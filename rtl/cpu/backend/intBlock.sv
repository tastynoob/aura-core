
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


`define ISSUE_WIDTH `DISP_TO_INT_BLOCK_PORTNUM



module intBlock #(
    parameter int INPUT_NUM = `ISSUE_WIDTH,
    parameter int EXTERNAL_WAKEUP = 2,// external wake up sources
    parameter int FU_NUM = 6
)(
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,
    // from dispatch
    input wire[`WDEF(INPUT_NUM)] i_disp_vld,
    output wire[`WDEF(INPUT_NUM)] o_can_disp,
    input intDQEntry_t i_disp_info[INPUT_NUM],
    // regfile read
    output iprIdx_t o_iprs_idx[FU_NUM * 2][`NUMSRCS_INT],// read regfile
    input wire[`WDEF(FU_NUM * 2)] i_iprs_ready[`NUMSRCS_INT],// ready or not
    input wire[`XDEF] i_iprs_data[FU_NUM * 2][`NUMSRCS_INT],
    // immBuffer read
    output irobIdx_t o_immB_idx[`ALU_NUM],
    input wire[`IMMDEF] i_imm_data[`ALU_NUM],

    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    output wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],

    // read ftqOffset (to ROB)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    output wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],

    // writeback
    input wire[`WDEF(FU_NUM)] i_wb_stall,
    output wire[`WDEF(FU_NUM)] o_wb_vld,
    output valwbInfo_t o_valwb_info[FU_NUM],
    output wire o_branchWB_vld,
    output branchwbInfo_t o_branchWB_info,
    output wire i_exceptwb_vld,
    output exceptwbInfo_t i_exceptwb_info,

    // external wake up
    input wire[`WDEF(EXTERNAL_WAKEUP)] i_ext_wake_vec,
    input iprIdx_t i_ext_wake_prdIdx[EXTERNAL_WAKEUP],
    input wire[`XDEF] i_ext_wake_data[EXTERNAL_WAKEUP]

);
    genvar i;
    wire[`WDEF(FU_NUM)] wb_vld;
    valwbInfo_t wbInfo[FU_NUM];
    assign o_valwb_info = wbInfo;

    wire IQ0_ready, IQ1_ready = 0;

    wire[`WDEF(INPUT_NUM)] select_alu, select_bru;
    wire[`WDEF(INPUT_NUM)] select_toIQ0, select_toIQ1;

    generate
        for(i=0;i<INPUT_NUM;i=i+1) begin : gen_for
            assign select_alu[i] = i_disp_vld[i] && (i_disp_info[i].issueQue_id == `ALUIQ_ID);
            assign select_bru[i] = i_disp_vld[i] && (i_disp_info[i].issueQue_id == `BRUIQ_ID);

            if (i < 2) begin : gen_if
                assign select_toIQ0[i] = IQ0_ready && select_alu[i];
                assign select_toIQ1[i] = IQ1_ready && (select_bru[i] || (select_alu[i] && select_toIQ0[i]));
            end
            else begin : gen_else
                // IQ0 current has selected
                wire[`SDEF(i)] IQ0_has_selected;
                count_one
                #(
                    .WIDTH ( i )
                )
                u_count_one_0(
                    .i_a   ( select_toIQ0[i-1:0]   ),
                    .o_sum ( IQ0_has_selected )
                );
                // IQ1 current has selected
                wire[`WDEF($clog2(i))] IQ1_has_selected;
                count_one
                #(
                    .WIDTH ( i )
                )
                u_count_one_1(
                    .i_a   ( select_toIQ1[i-1:0]   ),
                    .o_sum ( IQ1_has_selected )
                );
                assign select_toIQ0[i] = IQ0_ready && (IQ0_has_selected < 2 ? select_alu[i] : 0);
                assign select_toIQ1[i] = IQ1_ready && (IQ1_has_selected < 2 ? select_bru[i] || (select_alu[i] && select_toIQ0[i]) : 0);
            end
        end
    endgenerate

    `ASSERT((select_toIQ0 & select_toIQ1) == 0);
    `ORDER_CHECK((select_toIQ0 | select_toIQ1));

    assign o_can_disp = select_toIQ0 | select_toIQ1;

    wire[`WDEF(FU_NUM + EXTERNAL_WAKEUP)] global_writeback_vld;
    iprIdx_t global_writeback_iprdIdx[FU_NUM + EXTERNAL_WAKEUP];
    wire[`XDEF] global_writeback_data[FU_NUM + EXTERNAL_WAKEUP];

    wire[`WDEF(FU_NUM)] fu_writeback_stall = i_wb_stall;
    wire[`WDEF(FU_NUM)] fu_regfile_stall = 0;//dont care


    wire[`WDEF(FU_NUM)] internal_bypass_wb_vld;
    iprIdx_t internal_bypass_iprdIdx[FU_NUM];
    wire[`XDEF] internal_bypass_data[FU_NUM];

/****************************************************************************************************/
// IQ0: 1x(alu+scu) + 1x(alu)
/****************************************************************************************************/
    wire[`WDEF(INPUT_NUM)] IQ0_has_selected;
    intDQEntry_t IQ0_selected_info[INPUT_NUM];
    reorder
    #(
        .dtype ( intDQEntry_t ),
        .NUM   ( 4   )
    )
    u_reorder(
        .i_data_vld      ( select_toIQ0      ),
        .i_datas         ( i_disp_info         ),
        .o_data_vld      ( IQ0_has_selected      ),
        .o_reorder_datas ( IQ0_selected_info )
    );


    wire[`WDEF(2)] IQ0_inst_vld;
    wire[`WDEF($clog2(16))] IQ0_inst_iqIdx[2];
    exeInfo_t IQ0_inst_info[2];

    wire[`WDEF(2)] IQ0_issue_finished;
    wire[`WDEF(2)] IQ0_issue_failed;
    wire[`WDEF($clog2(16))] IQ0_issue_iqIdx[2];
    issueQue
    #(
        .DEPTH              ( 16    ),
        .INOUTPORT_NUM      ( 2     ),
        .EXTERNAL_WAKEUPNUM ( 2     ),
        .WBPORT_NUM         ( 6     ),
        .INTERNAL_WAKEUP    ( 1     ),
        .SINGLEEXE          ( 1     )
    )
    u_issueQue_singleExe0(
        .clk                   ( clk                   ),
        .rst                   ( rst                   ),
        .i_stall               ( ),

        .o_can_enq             ( IQ0_ready ),
        .i_enq_req             ( IQ0_has_selected[1:0] ),
        .i_enq_exeInfo         ( {IQ0_selected_info[0], IQ0_selected_info[1]} ),

        .o_can_issue           ( IQ0_inst_vld   ),
        .o_issue_idx           ( IQ0_inst_iqIdx ),
        .o_issue_exeInfo       ( IQ0_inst_info  ),

        .i_issue_finished_vec  ( IQ0_issue_finished ),
        .i_issue_replay_vec    ( IQ0_issue_failed   ),
        .i_feedback_idx        ( IQ0_issue_iqIdx    ),

        .o_export_wakeup_vld   (    ),
        .o_export_wakeup_rdIdx (  ),

        .i_ext_wakeup_vld      ( 0      ),
        .i_ext_wakeup_rdIdx    (     ),

        .i_wb_vld              ( 0              ),
        .i_wb_rdIdx            (    )
    );

    assign o_iprs_idx[0] = IQ0_inst_info[0].rsIdx;
    assign o_iprs_idx[1] = IQ0_inst_info[1].rsIdx;

    assign o_immB_idx[0] = IQ0_inst_info[0].irob_idx;
    assign o_immB_idx[1] = IQ0_inst_info[1].irob_idx;

/****************************************************************************************************/
// alu0
/****************************************************************************************************/

    // when one instruction was selected
    // there are 2 stage to process
    // s0: send request to regfile
    // s1: read data and check bypass, check inst can issue and deq from issueQue
    wire alu0_stall;
    reg[`WDEF(2)] s1_IQ0_inst_vld;
    iprIdx_t s1_IQ0_iprs_idx[2][`NUMSRCS_INT];
    exeInfo_t s1_IQ0_inst_info[2];
    always_ff @( posedge clk ) begin
        if (rst) begin
            s1_IQ0_inst_vld <= 0;
        end
        else begin
            s1_IQ0_inst_vld <= IQ0_inst_vld;
            s1_IQ0_iprs_idx[0] <= IQ0_inst_info[0].rsIdx;
            s1_IQ0_iprs_idx[1] <= IQ0_inst_info[1].rsIdx;
            s1_IQ0_inst_info <= IQ0_inst_info;
        end
    end

    wire alu0_bypass_vld[2];
    wire[`XDEF] alu0_bypass_data[2];

    bypass_sel
    #(
        .WIDTH ( FU_NUM + EXTERNAL_WAKEUP )
    )
    u_bypass_sel_0_src0(
        .i_src_vld     ( global_writeback_vld     ),
        .i_src_idx     ( global_writeback_iprdIdx     ),
        .i_src_data    ( global_writeback_data    ),
        .i_target_idx  ( IQ0_inst_info[0].rsIdx[0]  ),
        .o_target_vld  ( alu0_bypass_vld[0]  ),
        .o_target_data ( alu0_bypass_data[0] )
    );
    bypass_sel
    #(
        .WIDTH ( FU_NUM + EXTERNAL_WAKEUP )
    )
    u_bypass_sel_0_src1(
        .i_src_vld     ( global_writeback_vld      ),
        .i_src_idx     ( global_writeback_iprdIdx  ),
        .i_src_data    ( global_writeback_data     ),
        .i_target_idx  ( IQ0_inst_info[0].rsIdx[1] ),
        .o_target_vld  ( alu0_bypass_vld[1]        ),
        .o_target_data ( alu0_bypass_data[1]       )
    );

    fuInfo_t alu0_info = '{
        ftq_idx : s1_IQ0_inst_info[0].ftq_idx,
        rob_idx : s1_IQ0_inst_info[0].rob_idx,
        irob_idx : s1_IQ0_inst_info[0].irob_idx,
        rd_wen : s1_IQ0_inst_info[0].rd_wen,
        iprd_idx : s1_IQ0_inst_info[0].rdIdx,
        srcs : {
            alu0_bypass_vld[0] ? alu0_bypass_data[0] : i_iprs_data[0][0],
            s1_IQ0_inst_info[0].use_imm ? i_imm_data[0] : (alu0_bypass_vld[1] ? alu0_bypass_data[1] : i_iprs_data[0][1])
        },// need bypass
        issueQue_id : s1_IQ0_inst_info[0].issueQue_id,
        micOp : s1_IQ0_inst_info[0].micOp_type
    };

    //fu0
    alu u_alu_0(
        .clk               ( clk               ),
        .rst               ( rst               ),

        .o_fu_stall        ( alu0_stall        ),
        .i_vld             ( s1_IQ0_inst_vld ),
        .i_fuInfo          ( alu0_info          ),

        .o_willwrite_vld   ( internal_bypass_wb_vld[0] ),
        .o_willwrite_rdIdx ( internal_bypass_iprdIdx[0] ),
        .o_willwrite_data  ( internal_bypass_data[0]  ),

        .i_wb_stall        ( i_wb_stall[0]     ),
        .o_wb_vld          ( wb_vld[0]                  ),
        .o_wbInfo          ( wbInfo[0]         )
    );

/****************************************************************************************************/
// alu1
/****************************************************************************************************/

    fuInfo_t alu1_info = '{
        ftq_idx : s1_IQ0_inst_info[1].ftq_idx,
        rob_idx : s1_IQ0_inst_info[1].rob_idx,
        irob_idx : s1_IQ0_inst_info[1].irob_idx,
        rd_wen : s1_IQ0_inst_info[1].rd_wen,
        iprd_idx : s1_IQ0_inst_info[1].rdIdx,
        srcs : {0,0},
        issueQue_id : s1_IQ0_inst_info[1].issueQue_id,
        micOp : s1_IQ0_inst_info[1].micOp_type
    };

    //fu1
    alu u_alu_1(
        .clk               ( clk               ),
        .rst               ( rst               ),

        .o_fu_stall        ( o_fu_stall        ),
        .i_vld             (),
        .i_fuInfo          ( alu0_info          ),

        .o_willwrite_vld   ( ),
        .o_willwrite_rdIdx (  ),
        .o_willwrite_data  (   ),

        .i_wb_stall        ( i_wb_stall[1]     ),
        .o_wb_vld          (                   ),
        .o_wbInfo          ( wbInfo[1]         )
    );



/****************************************************************************************************/
// IQ1: 2x(alu+bru)
/****************************************************************************************************/




/****************************************************************************************************/
// IQ2: 2x(mdu)
/****************************************************************************************************/












    generate
        for(i=0; i<FU_NUM + EXTERNAL_WAKEUP; i=i+1) begin : gen_for
            if (i < 1) begin : gen_if
                assign global_writeback_vld[i] = internal_bypass_wb_vld[i];
                assign global_writeback_iprdIdx[i] = internal_bypass_iprdIdx[i];
                assign global_writeback_data[i] = internal_bypass_data[i];
            end
            else begin : gen_else
                assign global_writeback_vld[i] = 0;
                assign global_writeback_iprdIdx[i] = 0;
                assign global_writeback_data[i] = 0;
            end

        end
    endgenerate






endmodule


