
`include "core_define.svh"
`include "funcs.svh"


// DESIGN:
// issue -> read regfile/immBuffer/branchBuffer/ftq -> bypass/calcuate pc -> execute
// pc = (ftq_base_pc << offsetLen) + offset


// wakeup link
// alu -> alu
// alu -> lsu
// alu -> mdu
// mdu -> alu
// 1x(alu/scu) + 1xalu + 2x(alu/bru) + 2xmdu

// separate loadwakeNetwork from global wakeNetwork

module intBlock #(
    parameter int INPUT_NUM = `INTDQ_DISP_WID,
    parameter int FU_NUM    = 6
) (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    disp_if.s if_disp,
    input wire [`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INPUT_NUM],

    // regfile read
    output iprIdx_t o_iprs_idx[FU_NUM][`NUMSRCS_INT],  // read regfile
    input wire [`WDEF(`NUMSRCS_INT)] i_iprs_ready[FU_NUM],  // ready or not
    input wire [`XDEF] i_iprs_data[FU_NUM][`NUMSRCS_INT],

    // immBuffer read
    output irobIdx_t o_immB_idx[`ALU_NUM],
    input imm_t i_imm_data[`ALU_NUM],
    // immBuffer clear
    output wire [`WDEF(`ALU_NUM)] o_immB_clear_vld,
    output irobIdx_t o_immB_clear_idx[`ALU_NUM],

    // csr access
    input csr_in_pack_t i_csr_pack,
    csrrw_if.m if_csrrw,
    syscall_if.m if_syscall,

    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    input wire [`XDEF] i_read_ftqStartAddr[`BRU_NUM],
    input wire [`XDEF] i_read_ftqNextAddr[`BRU_NUM],
    // read ftqOffste (to rob)
    output wire [`WDEF($clog2(`ROB_SIZE))] o_read_robIdx[`BRU_NUM],
    input ftqOffset_t i_read_ftqOffset[`BRU_NUM],

    // writeback
    input wire [`WDEF(`INT_WBPORT_NUM)] i_wb_stall,
    output wire [`WDEF(`INT_WBPORT_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[`INT_WBPORT_NUM],

    output wire [`WDEF(`BRU_NUM)] o_branchWB_vld,
    output branchwbInfo_t o_branchwb_info[`BRU_NUM],

    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    // export int wakeNetwork
    output wire [`WDEF(`INT_SWAKE_WIDTH)] o_exp_swk_vec,
    output iprIdx_t o_exp_swk_iprd[`INT_SWAKE_WIDTH],

    // export bypass data
    output wire [`WDEF(`INT_WBPORT_NUM)] o_exp_bp_vec,
    output iprIdx_t o_exp_bp_iprd[`INT_WBPORT_NUM],
    output wire [`XDEF] o_exp_bp_data[`INT_WBPORT_NUM],

    // glob wbwake
    input wire [`WDEF(`WBPORT_NUM)] i_glob_wbwk_vec,
    input iprIdx_t i_glob_wbwk_iprd[`WBPORT_NUM],

    // load specwake/cancel
    loadwake_if.s if_loadwake,

    // global bypass network
    input wire [`WDEF(`BYPASS_WIDTH)] i_glob_bp_vec,
    input iprIdx_t i_glob_bp_iprd[`BYPASS_WIDTH],
    input wire [`XDEF] i_glob_bp_data[`BYPASS_WIDTH]
);
    assign o_exceptwb_vld = 0;

    genvar i, j;
    wire [`WDEF(FU_NUM)] fu_finished;
    comwbInfo_t comwbInfo[FU_NUM];

    wire IQ0_ready, IQ1_ready;

    wire [`WDEF(INPUT_NUM)] select_alu, select_bru;
    /* verilator lint_off UNOPTFLAT */
    wire [`WDEF(INPUT_NUM)] select_total;
    wire [`WDEF(INPUT_NUM)] select_toIQ0, select_toIQ1;

    generate
        for (i = 0; i < INPUT_NUM; i = i + 1) begin
            // NOTE: serialized inst must goto IQ0 and issue to alu0
            assign select_alu[i] =
                if_disp.int_req[i] && (if_disp.int_info[i].issueQueId == `ALUIQ_ID || if_disp.int_info[i].issueQueId == `SCUIQ_ID);
            assign select_bru[i] = if_disp.int_req[i] && (if_disp.int_info[i].issueQueId == `BRUIQ_ID);

            if (i == 0) begin
                assign select_total[i] = select_toIQ0[i] || select_toIQ1[i];
            end
            else begin
                assign select_total[i] = (select_toIQ0[i] || select_toIQ1[i]) && select_total[i-1];
            end

            if (i == 0) begin
                assign select_toIQ0[i] = IQ0_ready && select_alu[i];
                assign select_toIQ1[i] = IQ1_ready && (select_bru[i] || (select_alu[i] && (!select_toIQ0[i])));
            end
            else if (i < 2) begin
                assign select_toIQ0[i] = IQ0_ready && select_alu[i] && select_total[i-1];
                assign select_toIQ1[i] = IQ1_ready && (select_bru[i] || (select_alu[i] && (!select_toIQ0[i]))) && select_total[i-1];
            end
            else begin : gen_count_one
                // IQ0 current has selected
                wire [`SDEF(i)] IQ0_has_selected_num;
                count_one #(
                    .WIDTH(i)
                ) u_count_one_0 (
                    .i_a  (select_toIQ0[i-1:0]),
                    .o_sum(IQ0_has_selected_num)
                );
                // IQ1 current has selected
                wire [`SDEF(i)] IQ1_has_selected_num;
                count_one #(
                    .WIDTH(i)
                ) u_count_one_1 (
                    .i_a  (select_toIQ1[i-1:0]),
                    .o_sum(IQ1_has_selected_num)
                );
                // FIXME: select_toIQ0 | select_toIQ1 must in order
                // prepare for bru
                assign select_toIQ0[i] = IQ0_ready && (IQ0_has_selected_num < 2) && select_alu[i] && select_total[i-1];
                assign select_toIQ1[i] = IQ1_ready && (IQ1_has_selected_num < 2) && (select_bru[i] || (select_alu[i] && (!select_toIQ0[i]))) && select_total[i-1];
            end
        end
    endgenerate

    `ASSERT(funcs::count_one(select_toIQ0) <= 2);
    `ASSERT(funcs::count_one(select_toIQ1) <= 2);
    `ASSERT((select_toIQ0 & select_toIQ1) == 0);
    `ORDER_CHECK((select_toIQ0 | select_toIQ1));

    assign if_disp.int_rdy = select_total;

    wire [`WDEF(FU_NUM)] fu_writeback_stall = i_wb_stall;
    wire [`WDEF(FU_NUM)] fu_regfile_stall = 0;  //dont care

    imm_t s1_irob_imm[`ALU_NUM];
    always_ff @(posedge clk) begin
        s1_irob_imm <= i_imm_data;
    end

    // internal bypass network
    wire [`WDEF(FU_NUM)] bypass_vld;
    iprIdx_t bypass_iprd[FU_NUM];
    wire [`XDEF] bypass_data[FU_NUM];

    // internal wake network (specwake + wbwake)
    wire [`WDEF(`INTWAKE_WIDTH)] wake_vec;
    iprIdx_t wake_iprd[`INTWAKE_WIDTH];
    lpv_t wake_lpv[`INTWAKE_WIDTH][`NUMSRCS_INT];

    `define YOU_NEED_DEFINE_THIS_MACRO


    /********************/
    // IQ0: scu_alu + alu
    /********************/
    generate
        if (1) begin : gen_IQ0
            wire [`WDEF(INPUT_NUM)] selected_vec;
            microOp_t selected_insts[INPUT_NUM];
            wire [`WDEF(`NUMSRCS_INT)] selected_iprsRdy[INPUT_NUM];
            reorder #(
                .dtype(microOp_t),
                .NUM  (4)
            ) u_reorder_0 (
                .i_data_vld     (select_toIQ0),
                .i_datas        (if_disp.int_info),
                .o_data_vld     (selected_vec),
                .o_reorder_datas(selected_insts)
            );
            reorder #(
                .dtype(logic [`WDEF(`NUMSRCS_INT)]),
                .NUM  (4)
            ) u_reorder_1 (
                .i_data_vld     (select_toIQ0),
                .i_datas        (i_enq_iprs_rdy),
                .o_reorder_datas(selected_iprsRdy)
            );

            localparam int IQ_SIZE = 32;
            localparam int IQ_INOUT = 2;
            localparam int PORT_OFFSET = 0;

            wire canEnq;
            wire [`WDEF(IQ_INOUT)] enqReq;
            microOp_t enqMicroOp[IQ_INOUT];
            wire [`WDEF(`NUMSRCS_INT)] enqIprsRdy[IQ_INOUT];
            assign IQ0_ready = canEnq;
            assign enqReq = selected_vec[IQ_INOUT-1:0];
            assign enqMicroOp = selected_insts[0:IQ_INOUT-1];
            assign enqIprsRdy = selected_iprsRdy[0:IQ_INOUT-1];

            `define NEED_IMM
            `include "generateIntIQ.svh.tmp"
            `undef NEED_IMM

            if (1) begin : gen_fu0_alu_scu
                localparam int IQ_FUID = 0;
                localparam int BLK_FUID = 0;
                `define HAS_SCU
                `include "generateIntFu.svh.tmp"
                `undef HAS_SCU
            end
            if (1) begin : gen_fu1_alu
                localparam int IQ_FUID = 1;
                localparam int BLK_FUID = 1;
                `include "generateIntFu.svh.tmp"
            end

        end
    endgenerate

    /********************/
    // IQ1: bru_alu + bru_alu
    /********************/
    generate
        if (1) begin : gen_IQ1
            wire [`WDEF(INPUT_NUM)] selected_vec;
            microOp_t selected_insts[INPUT_NUM];
            wire [`WDEF(`NUMSRCS_INT)] selected_iprsRdy[INPUT_NUM];
            reorder #(
                .dtype(microOp_t),
                .NUM  (4)
            ) u_reorder_2 (
                .i_data_vld     (select_toIQ1),
                .i_datas        (if_disp.int_info),
                .o_data_vld     (selected_vec),
                .o_reorder_datas(selected_insts)
            );
            reorder #(
                .dtype(logic [`WDEF(`NUMSRCS_INT)]),
                .NUM  (4)
            ) u_reorder_3 (
                .i_data_vld     (select_toIQ1),
                .i_datas        (i_enq_iprs_rdy),
                .o_reorder_datas(selected_iprsRdy)
            );

            localparam int IQ_SIZE = 32;
            localparam int IQ_INOUT = 2;
            localparam int PORT_OFFSET = 2;

            wire canEnq;
            wire [`WDEF(IQ_INOUT)] enqReq;
            microOp_t enqMicroOp[IQ_INOUT];
            wire [`WDEF(`NUMSRCS_INT)] enqIprsRdy[IQ_INOUT];
            assign IQ1_ready = canEnq;
            assign enqReq = selected_vec[IQ_INOUT-1:0];
            assign enqMicroOp = selected_insts[0:IQ_INOUT-1];
            assign enqIprsRdy = selected_iprsRdy[0:IQ_INOUT-1];

            `define NEED_IMM
            `include "generateIntIQ.svh.tmp"
            `undef NEED_IMM

            if (1) begin : gen_fu2_bru_alu
                localparam int IQ_FUID = 0;
                localparam int BLK_FUID = 2;
                `define HAS_BRU
                `include "generateIntFu.svh.tmp"
                `undef HAS_BRU
            end
            if (1) begin : gen_fu3_bru_alu
                localparam int IQ_FUID = 1;
                localparam int BLK_FUID = 3;
                `define HAS_BRU
                `include "generateIntFu.svh.tmp"
                `undef HAS_BRU
            end
        end
    endgenerate

    /********************/
    // IQ2: mdu + mdu
    /********************/

    assign wake_vec[`INT_SWAKE_WIDTH-1 : `ALU_NUM] = 0;
    assign bypass_vld[`INT_SWAKE_WIDTH-1 : `ALU_NUM] = 0;
    assign fu_finished[`INT_SWAKE_WIDTH-1 : `ALU_NUM] = 0;

    /****************************************************************************************************/
    // others
    /****************************************************************************************************/
    // intBlk wake channel (6 + 8)
    assign wake_vec[`INTWAKE_WIDTH-1 : `INT_SWAKE_WIDTH] = i_glob_wbwk_vec;
    generate
        for (i = 0; i < `WBPORT_NUM; i = i + 1) begin
            assign wake_iprd[`INT_SWAKE_WIDTH+i] = i_glob_wbwk_iprd[i];
        end
    endgenerate

    assign o_comwbInfo = comwbInfo;
    assign o_fu_finished = fu_finished;

    assign o_exp_bp_vec = bypass_vld;
    assign o_exp_bp_iprd = bypass_iprd;
    assign o_exp_bp_data = bypass_data;

    assign o_exp_swk_vec = wake_vec[`INT_SWAKE_WIDTH-1 : 0];
    assign o_exp_swk_iprd = wake_iprd[0:`INT_SWAKE_WIDTH-1];


endmodule


