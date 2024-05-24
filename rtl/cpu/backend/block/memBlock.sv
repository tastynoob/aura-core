// IQ0/2: load
// IQ1.1/3: store data
// IQ1.2/3: store addr

`define BUILD_LDST(op, _lqIdx, _sqIdx) \
    '{ \
        default : 0, \
        ftqIdx  : ``op``.ftqIdx, \
        robIdx  : ``op``.robIdx, \
        irobIdx : ``op``.irobIdx, \
        lqIdx   : _lqIdx, \
        sqIdx   : _sqIdx, \
        rdwen   : ``op``.rdwen, \
        iprd    : ``op``.iprd, \
        iprs    : ``op``.iprs, \
        useImm  : ``op``.useImm, \
        issueQueId : ``op``.issueQueId, \
        micOp   : ``op``.micOp, \
        shouldwait : ``op``.shouldwait, \
        depIdx  : ``op``.depIdx, \
        seqNum  : ``op``.seqNum \
    }

`define BUILD_NEW_MICOP(op, idx) \
    '{ \
        default : 0, \
        ftqIdx  : ``op``.ftqIdx, \
        robIdx  : ``op``.robIdx, \
        irobIdx : ``op``.irobIdx, \
        lqIdx   : ``op``.lqIdx, \
        sqIdx   : ``op``.sqIdx, \
        rdwen   : ``op``.rdwen, \
        iprd    : ``op``.iprd, \
        iprs    : {``op``.iprs[``idx``], 0}, \
        useImm  : ``op``.useImm, \
        issueQueId : ``op``.issueQueId, \
        micOp   : ``op``.micOp, \
        shouldwait : ``op``.shouldwait, \
        depIdx  : ``op``.depIdx, \
        seqNum  : ``op``.seqNum \
    }

`define YOU_NEED_DEFINE_THIS_MACRO

module memBlock #(
    parameter int INPUT_NUM = `MEMDQ_DISP_WID,
    parameter int FU_NUM    = `LDU_NUM + `STU_NUM  // 2ld + 2sta/std
) (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from dispatch
    disp_if.s if_disp,
    input wire [`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INPUT_NUM],
    input wire i_enq_memdep_rdy[INPUT_NUM],

    // regfile read
    output iprIdx_t o_iprs_idx[`LDU_NUM + `STU_NUM*2],  // read regfile
    input wire i_iprs_ready[`LDU_NUM + `STU_NUM*2],  // ready or not
    input wire [`XDEF] i_iprs_data[`LDU_NUM + `STU_NUM*2],

    // immBuffer read
    output irobIdx_t o_immB_idx[FU_NUM],
    input imm_t i_imm_data[FU_NUM],
    output wire [`WDEF(FU_NUM)] o_immB_clear_vld,
    output irobIdx_t o_immB_clear_idx[FU_NUM],

    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`LDU_NUM + `STU_NUM],
    input wire [`XDEF] i_read_ftqStartAddr[`LDU_NUM + `STU_NUM],
    // read ftqOffste (to rob)
    output wire [`WDEF($clog2(`ROB_SIZE))] o_read_robIdx[`LDU_NUM + `STU_NUM],
    input ftqOffset_t i_read_ftqOffset[`LDU_NUM + `STU_NUM],

    // writeback
    input wire [`WDEF(`LDU_NUM)] i_wb_stall,
    output wire [`WDEF(FU_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[FU_NUM],
    // exception
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    input wire [`SDEF(`COMMIT_WIDTH)] i_committed_stores,
    input wire [`SDEF(`COMMIT_WIDTH)] i_committed_loads,

    // load spec wake
    loadwake_if.m if_loadwake,

    // export bypass data (unused)
    output wire [`WDEF(`MEM_WBPORT_NUM)] o_exp_bp_vec,
    output iprIdx_t o_exp_bp_iprd[`MEM_WBPORT_NUM],
    output wire [`XDEF] o_exp_bp_data[`MEM_WBPORT_NUM],

    // external specwake
    input wire [`WDEF(`INT_SWAKE_WIDTH)] i_ext_swk_vec,
    input iprIdx_t i_ext_swk_iprd[`INT_SWAKE_WIDTH],

    // glob wbwake
    input wire [`WDEF(`WBPORT_NUM)] i_glob_wbwk_vec,
    input iprIdx_t i_glob_wbwk_iprd[`WBPORT_NUM],

    // global bypass data
    input wire [`WDEF(`BYPASS_WIDTH)] i_glob_bp_vec,
    input iprIdx_t i_glob_bp_iprd[`BYPASS_WIDTH],
    input wire [`XDEF] i_glob_bp_data[`BYPASS_WIDTH]
);
    assign o_exp_bp_vec = 0;  // dont care
    //assign o_exceptwb_vld = 0;

    genvar i;

    wire [`WDEF(FU_NUM)] fu_finished;
    comwbInfo_t comwbInfo[FU_NUM];

    wire [`WDEF(FU_NUM)] has_except;
    exceptwbInfo_t exceptwbInfo[FU_NUM];

    wire LSQ_ready, IQ0_ready, IQ1_ready;

    wire [`WDEF(INPUT_NUM)] select_ldu, select_stu;
    /* verilator lint_off UNOPTFLAT */
    wire [`WDEF(INPUT_NUM)] select_total;
    wire [`WDEF(INPUT_NUM)] select_toIQ0, select_toIQ1;

    generate
        for (i = 0; i < INPUT_NUM; i = i + 1) begin
            assign select_ldu[i] = if_disp.mem_req[i] && (if_disp.mem_info[i].issueQueId == `LDUIQ_ID);
            assign select_stu[i] = if_disp.mem_req[i] && (if_disp.mem_info[i].issueQueId == `STUIQ_ID);

            if (i == 0) begin
                assign select_total[i] = select_toIQ0[i] || select_toIQ1[i];
            end
            else begin
                assign select_total[i] = (select_toIQ0[i] || select_toIQ1[i]) && select_total[i-1];
            end

            if (i == 0) begin
                assign select_toIQ0[i] = LSQ_ready && IQ0_ready && select_ldu[i];
                assign select_toIQ1[i] = LSQ_ready && IQ1_ready && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i])));
            end
            else if (i < 2) begin
                assign select_toIQ0[i] = LSQ_ready && IQ0_ready && select_ldu[i] && select_total[i-1];
                assign select_toIQ1[i] = LSQ_ready && IQ1_ready && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i]))) && select_total[i-1];
            end
            else begin : gen_count_one
                // IQ0 current has selected
                wire [`SDEF(i)] selected_vec_num;
                count_one #(
                    .WIDTH(i)
                ) u_count_one_0 (
                    .i_a  (select_toIQ0[i-1:0]),
                    .o_sum(selected_vec_num)
                );
                // IQ1 current has selected
                wire [`SDEF(i)] IQ1_has_selected_num;
                count_one #(
                    .WIDTH(i)
                ) u_count_one_1 (
                    .i_a  (select_toIQ1[i-1:0]),
                    .o_sum(IQ1_has_selected_num)
                );

                assign select_toIQ0[i] = LSQ_ready && IQ0_ready && (selected_vec_num < 2) && select_ldu[i] && select_total[i-1];
                assign select_toIQ1[i] = LSQ_ready && IQ1_ready && (IQ1_has_selected_num < 2) && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i]))) && select_total[i-1];
            end
        end
    endgenerate

    `ASSERT(funcs::count_one(select_toIQ0) <= 2);
    `ASSERT(funcs::count_one(select_toIQ1) <= 2);
    `ASSERT((select_toIQ0 & select_toIQ1) == 0);
    `ORDER_CHECK((select_toIQ0 | select_toIQ1));

    assign if_disp.mem_rdy = select_total;

    wire [`WDEF(`LDU_NUM)] fu_writeback_stall = i_wb_stall;
    wire [`WDEF(FU_NUM)] fu_regfile_stall = 0;  //dont care

    imm_t s1_irob_imm[FU_NUM];
    always_ff @(posedge clk) begin
        s1_irob_imm <= i_imm_data;
    end

    // ldu -> ldque
    load2que_if if_load2que[`LDU_NUM] ();
    // ldu -> stque
    stfwd_if if_stfwd[`LDU_NUM] ();
    // ldu -> cache
    load2dcache_if if_load2cache[`LDU_NUM] ();
    // stau -> ldque
    staviocheck_if if_viocheck[`STU_NUM] ();

    // stau -> storeque
    sta2mmu_if if_sta2mmu[`STU_NUM] ();
    store2que_if if_sta2que[`STU_NUM] ();
    store2que_if if_std2que[`STU_NUM] ();

    // internal back to back bypass
    wire [`WDEF(`LDU_NUM)] bypass_vld;
    iprIdx_t bypass_iprd[`LDU_NUM];
    wire [`XDEF] bypass_data[`LDU_NUM];

    // internal wake network (specwake + wbwake)
    wire [`WDEF(`MEMWAKE_WIDTH)] wake_vec;
    iprIdx_t wake_iprd[`MEMWAKE_WIDTH];
    lpv_t wake_lpv[`MEMWAKE_WIDTH][`NUMSRCS_INT];

    // memdep wake (store -> load)
    wire [`WDEF(`STU_NUM)] depwk_vec;
    robIdx_t depwk_robIdx[`STU_NUM];


    /********************/
    // virtual LSQ
    /********************/
    lqIdx_t lqhead[`MEMDQ_DISP_WID];
    sqIdx_t sqhead[`MEMDQ_DISP_WID];
    microOp_t ldstInsts[`MEMDQ_DISP_WID];

    virtualLSQ #(
        .INPORTS        (`MEMDQ_DISP_WID),
        .LD_ISSUE_WIDTH (2),
        .ST_ISSUE_WIDTH (2),
        .LD_COMMIT_WIDTH(`COMMIT_WIDTH),
        .ST_COMMIT_WIDTH(`COMMIT_WIDTH)
    ) u_virtualLSQ (
        .clk(clk),
        .rst(rst || i_squash_vld),

        .o_can_enq (LSQ_ready),
        .i_disp_load (select_toIQ0),
        .i_disp_store (select_toIQ1),

        .o_alloc_lqIdx(lqhead),
        .o_alloc_sqIdx(sqhead),

        .i_ld_commit_num(i_committed_loads),
        .i_st_commit_num(i_committed_stores)
    );

    generate
        for (i = 0; i < `MEMDQ_DISP_WID; i = i + 1) begin
            assign ldstInsts[i] = `BUILD_LDST(
                    if_disp.mem_info[i], lqhead[i], sqhead[i]);
        end
    endgenerate

    /********************/
    // IQ0: 2 ldu
    /********************/
    generate
        if (1) begin : gen_IQ0
            wire [`WDEF(INPUT_NUM)] selected_vec;
            microOp_t selected_insts[INPUT_NUM];
            wire [`WDEF(`NUMSRCS_INT)] selected_iprsRdy[INPUT_NUM];
            wire selected_depRdy[INPUT_NUM];

            reorder #(
                .dtype(microOp_t),
                .NUM  (4)
            ) u_reorder_0 (
                .i_data_vld     (select_toIQ0),
                .i_datas        (ldstInsts),
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

            reorder #(
                .dtype(logic),
                .NUM  (4)
            ) u_reorder_2 (
                .i_data_vld     (select_toIQ0),
                .i_datas        (i_enq_memdep_rdy),
                .o_reorder_datas(selected_depRdy)
            );

            localparam int IQ_SIZE = 32;
            localparam int IQ_INOUT = 2;
            localparam int PORT_OFFSET = 0;

            wire canEnq;
            wire [`WDEF(IQ_INOUT)] enqReq;
            microOp_t enqMicroOp[IQ_INOUT];
            wire [`WDEF(IQ_INOUT)] enqIprsRdy;
            wire [`WDEF(IQ_INOUT)] enqDepRdy;
            assign IQ0_ready = canEnq;
            assign enqReq = selected_vec[IQ_INOUT-1:0];
            for (i = 0; i < IQ_INOUT; i = i + 1) begin
                assign enqMicroOp[i] = `BUILD_NEW_MICOP(selected_insts[i], 0);
                assign enqIprsRdy[i] = selected_iprsRdy[i][0];
                assign enqDepRdy[i] = selected_depRdy[i];
                `ASSERT(select_toIQ0[i] ? (selected_insts[i].iprs[1] == 0) : 1);
                `ASSERT(select_toIQ0[i] ? (selected_iprsRdy[i][1] == 1) : 1);
            end

            `define NEED_IMM
            `include "generateMemIQ.svh.tmp"
            `undef NEED_IMM

            if (1) begin : gen_fu4_ldu
                localparam int IQ_FUID = 0;
                localparam int BLK_FUID = 0;

                `define HAS_LDU
                `include "generateMemFu.svh.tmp"
                `undef HAS_LDU
            end
            if (1) begin : gen_fu5_ldu
                localparam int IQ_FUID = 1;
                localparam int BLK_FUID = 1;

                `define HAS_LDU
                `include "generateMemFu.svh.tmp"
                `undef HAS_LDU
            end
        end
    endgenerate


    /****************************************************************************************************/
    // IQ1/2: 2 stdu + 2 stau
    /****************************************************************************************************/
    //assign fu_finished[3:2] = 0;
    //assign has_except[3:2] = 0;
    //assign o_immB_clear_vld[3:2] = 0;

    wire staIQ_ready, stdIQ_ready;
    wire [`WDEF(INPUT_NUM)] st_selected_vec;
    microOp_t st_selected_insts[INPUT_NUM];
    wire [`WDEF(`NUMSRCS_INT)] st_selected_iprsRdy[INPUT_NUM];

    assign IQ1_ready = staIQ_ready & stdIQ_ready;

    generate
        // sta IQ
        if (1) begin : gen_IQ1
            reorder #(
                .dtype(microOp_t),
                .NUM  (4)
            ) u_reorder_0 (
                .i_data_vld     (select_toIQ1),
                .i_datas        (ldstInsts),
                .o_data_vld     (st_selected_vec),
                .o_reorder_datas(st_selected_insts)
            );

            reorder #(
                .dtype(logic [`WDEF(`NUMSRCS_INT)]),
                .NUM  (4)
            ) u_reorder_1 (
                .i_data_vld     (select_toIQ1),
                .i_datas        (i_enq_iprs_rdy),
                .o_reorder_datas(st_selected_iprsRdy)
            );

            localparam int IQ_SIZE = 32;
            localparam int IQ_INOUT = 2;
            localparam int PORT_OFFSET = 2;

            wire canEnq;
            wire [`WDEF(IQ_INOUT)] enqReq;
            microOp_t enqMicroOp[IQ_INOUT];
            wire [`WDEF(IQ_INOUT)] enqIprsRdy;
            wire [`WDEF(IQ_INOUT)] enqDepRdy;
            assign staIQ_ready = canEnq;
            assign enqReq = IQ1_ready ? st_selected_vec[IQ_INOUT-1:0] : 0;
            for (i = 0; i < IQ_INOUT; i = i + 1) begin
                assign enqMicroOp[i] = `BUILD_NEW_MICOP(st_selected_insts[i], 0);
                assign enqIprsRdy[i] = st_selected_iprsRdy[i][0];
                assign enqDepRdy[i] = 1;
            end

            `define NEED_IMM
            `include "generateMemIQ.svh.tmp"
            `undef NEED_IMM

            if (1) begin : gen_fu6_stau
                localparam int IQ_FUID = 0;
                localparam int BLK_FUID = 2;

                `define HAS_STAU
                `include "generateMemFu.svh.tmp"
                `undef HAS_STAU
            end
            if (1) begin : gen_fu7_stau
                localparam int IQ_FUID = 1;
                localparam int BLK_FUID = 3;

                `define HAS_STAU
                `include "generateMemFu.svh.tmp"
                `undef HAS_STAU
            end
        end

        // std IQ
        if (1) begin : gen_IQ2
            localparam int IQ_SIZE = 32;
            localparam int IQ_INOUT = 2;
            localparam int PORT_OFFSET = 4;

            wire canEnq;
            wire [`WDEF(IQ_INOUT)] enqReq;
            microOp_t enqMicroOp[IQ_INOUT];
            wire [`WDEF(IQ_INOUT)] enqIprsRdy;
            wire [`WDEF(IQ_INOUT)] enqDepRdy;
            assign stdIQ_ready = canEnq;
            assign enqReq = IQ1_ready ? st_selected_vec[IQ_INOUT-1:0] : 0;
            for (i = 0; i < IQ_INOUT; i = i + 1) begin
                assign enqMicroOp[i] = `BUILD_NEW_MICOP(st_selected_insts[i], 1);
                assign enqIprsRdy[i] = st_selected_iprsRdy[i][1];
                assign enqDepRdy[i] = 1;
            end

            `include "generateMemIQ.svh.tmp"

            if (1) begin : gen_fu8_stdu
                localparam int IQ_FUID = 0;
                localparam int BLK_FUID = 4;

                `define HAS_STDU
                `include "generateMemFu.svh.tmp"
                `undef HAS_STDU
            end
            if (1) begin : gen_fu9_stdu
                localparam int IQ_FUID = 1;
                localparam int BLK_FUID = 5;

                `define HAS_STDU
                `include "generateMemFu.svh.tmp"
                `undef HAS_STDU
            end
        end
    endgenerate


    /********************/
    // loadQueue
    /********************/


    loadQue u_loadQue (
        .clk              (clk),
        .rst              (rst),
        .i_flush          (i_squash_vld),
        .if_load2que      (if_load2que),
        .if_viocheck      (if_viocheck),
        .i_committed_loads(i_committed_loads)
    );



    /********************/
    // storeQueue
    /********************/

    storeQue u_storeQue (
        .clk    (clk),
        .rst    (rst),
        .i_flush(i_squash_vld),

        .if_sta2que(if_sta2que),
        .if_std2que(if_std2que),

        .if_stfwd(if_stfwd),

        .o_fu_finished (fu_finished[FU_NUM-1: 2]),
        .o_comwbInfo   (comwbInfo[2:FU_NUM-1]),

        //.if_st2dcache      (),
        .i_committed_stores(i_committed_stores),
        .o_released_stores ()
    );



    /****************************************************************************************************/
    // other
    /****************************************************************************************************/

    dcache u_dcache (
        .clk    (clk),
        .rst    (rst),
        .if_core(if_load2cache),
        .if_sta (if_sta2mmu)
    );

    // lsque u_lsque (
    //     .if_load2que(if_load2que),
    //     .if_stfwd   (if_stfwd)
    // );


    logic [`WDEF($clog2(FU_NUM))] oldest_except;
    robIdx_t oldest_except_robIdx;
    always_comb begin
        int ca;
        oldest_except = 0;
        oldest_except_robIdx = ~0;
        for (ca = 0; ca < FU_NUM; ca = ca + 1) begin
            if (has_except[ca] && `OLDER_THAN(exceptwbInfo[ca].rob_idx, oldest_except_robIdx)) begin
                oldest_except = ca;
                oldest_except_robIdx = exceptwbInfo[ca].rob_idx;
            end
        end
    end

    reg except_vld;
    exceptwbInfo_t final_except;
    always_ff @(posedge clk) begin
        if (rst || i_squash_vld) begin
            except_vld <= 0;
        end
        else begin
            except_vld <= |has_except;
            final_except <= exceptwbInfo[oldest_except];
        end
    end




    // export load specwake
    assign if_loadwake.wk = wake_vec[`LDU_NUM-1:0];
    assign if_loadwake.wkIprd = wake_iprd[0:`LDU_NUM-1];


    // intBlk specwake
    assign wake_vec[`MEM_SWAKE_WIDTH+`INT_SWAKE_WIDTH-1:`MEM_SWAKE_WIDTH] = i_ext_swk_vec;
    assign wake_iprd[`MEM_SWAKE_WIDTH:`MEM_SWAKE_WIDTH+`INT_SWAKE_WIDTH-1] = i_ext_swk_iprd;
    // global wbwake
    assign wake_vec[`MEMWAKE_WIDTH-1:`MEM_SWAKE_WIDTH+`INT_SWAKE_WIDTH] = i_glob_wbwk_vec;
    assign wake_iprd[`MEM_SWAKE_WIDTH+`INT_SWAKE_WIDTH:`MEMWAKE_WIDTH-1] = i_glob_wbwk_iprd;

    assign o_fu_finished = fu_finished;
    assign o_comwbInfo = comwbInfo;

    assign o_exceptwb_vld = except_vld;
    assign o_exceptwb_info = final_except;

endmodule
