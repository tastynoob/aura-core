
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


`define ISSUE_WIDTH `INTDQ_DISP_WID
`define IQ0_SIZE 16
`define IQ1_SIZE 16


module intBlock #(
    parameter int INPUT_NUM = `ISSUE_WIDTH,
    parameter int EXTERNAL_WRITEBACK = 2,// 2 ldu
    parameter int EXTERNAL_WAKEUP = 2,// external wake up sources
    parameter int FU_NUM = 6
)(
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,
    // from dispatch
    output wire[`WDEF(INPUT_NUM)] o_disp_vld,
    input wire[`WDEF(INPUT_NUM)] i_disp_req,
    input intDQEntry_t i_disp_info[INPUT_NUM],
    input wire[`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INPUT_NUM],
    // regfile read
    output iprIdx_t o_iprs_idx[FU_NUM][`NUMSRCS_INT],// read regfile
    input wire[`WDEF(`NUMSRCS_INT)] i_iprs_ready[FU_NUM],// ready or not
    input wire[`XDEF] i_iprs_data[FU_NUM][`NUMSRCS_INT],
    // immBuffer read
    output irobIdx_t o_immB_idx[`ALU_NUM],
    input imm_t i_imm_data[`ALU_NUM],

    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    input wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],
    input wire[`XDEF] i_read_ftqNextAddr[`BRU_NUM],

    // writeback
    input wire[`WDEF(FU_NUM)] i_wb_stall,
    output wire[`WDEF(FU_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[FU_NUM],
    output wire[`WDEF(`BRU_NUM)] o_branchWB_vld,
    output branchwbInfo_t o_branchwb_info[`WDEF(`BRU_NUM)],
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    // external wake up (may be speculative)
    input wire[`WDEF(EXTERNAL_WAKEUP)] i_ext_wake_vec,
    input iprIdx_t i_ext_wake_rdIdx[EXTERNAL_WAKEUP],

    // external writeback
    input wire[`WDEF(EXTERNAL_WRITEBACK)] i_ext_wb_vec,
    input iprIdx_t i_ext_wb_rdIdx[EXTERNAL_WRITEBACK],
    input wire[`XDEF] i_ext_wb_data[EXTERNAL_WRITEBACK]
);
    genvar i;
    wire[`WDEF(FU_NUM)] fu_finished;
    comwbInfo_t comwbInfo[FU_NUM];

    wire IQ0_ready, IQ1_ready;

    wire[`WDEF(INPUT_NUM)] select_alu, select_bru;
    wire[`WDEF(INPUT_NUM)] select_toIQ0, select_toIQ1;

    generate
        for(i=0;i<INPUT_NUM;i=i+1) begin : gen_for
            assign select_alu[i] = i_disp_req[i] && (i_disp_info[i].issueQue_id == `ALUIQ_ID);
            assign select_bru[i] = i_disp_req[i] && (i_disp_info[i].issueQue_id == `BRUIQ_ID);

            if (i < 2) begin : gen_if
                assign select_toIQ0[i] = IQ0_ready && select_alu[i];
                assign select_toIQ1[i] = IQ1_ready && (select_bru[i] || (select_alu[i] && (!select_toIQ0[i])));
            end
            else begin : gen_else
                // IQ0 current has selected
                wire[`SDEF(i)] IQ0_has_selected_num;
                count_one
                #(
                    .WIDTH ( i )
                )
                u_count_one_0(
                    .i_a   ( select_toIQ0[i-1:0]   ),
                    .o_sum ( IQ0_has_selected_num )
                );
                // IQ1 current has selected
                wire[`WDEF($clog2(i))] IQ1_has_selected_num;
                count_one
                #(
                    .WIDTH ( i )
                )
                u_count_one_1(
                    .i_a   ( select_toIQ1[i-1:0]   ),
                    .o_sum ( IQ1_has_selected_num )
                );
                // FIXME: select_toIQ0 | select_toIQ1 must in order
                assign select_toIQ0[i] = IQ0_ready && (IQ0_has_selected_num < 2 ? select_alu[i] : 0);
                assign select_toIQ1[i] = IQ1_ready && (IQ1_has_selected_num < 2 ? select_bru[i] || (select_alu[i] && (!select_toIQ0[i])) : 0);
            end
        end
    endgenerate

    `ASSERT((select_toIQ0 & select_toIQ1) == 0);
    `ORDER_CHECK((select_toIQ0 | select_toIQ1));

    assign o_disp_vld = select_toIQ0 | select_toIQ1;

    // FU_NUM*3 : will writeback + writeback bypass + writeback read regfile bypass
    // EXTERNAL_WAKEUP*2 : writeback bypass + writeback read regfile bypass
    wire[`WDEF(FU_NUM * 3 + EXTERNAL_WRITEBACK * 2)] global_bypass_vld;
    iprIdx_t global_bypass_rdIdx[FU_NUM * 3 + EXTERNAL_WRITEBACK * 2];
    wire[`XDEF] global_bypass_data[FU_NUM * 3 + EXTERNAL_WRITEBACK * 2];

    // global writeback (used for wakeup)
    wire[`WDEF(FU_NUM + EXTERNAL_WRITEBACK)] global_wb_vld;
    iprIdx_t global_wb_rdIdx[FU_NUM + EXTERNAL_WRITEBACK];

    // global wakeup (may be speculative)
    wire[`WDEF(FU_NUM + EXTERNAL_WAKEUP)] global_wake_vld;
    iprIdx_t global_wake_rdIdx[FU_NUM + EXTERNAL_WAKEUP];


    wire[`WDEF(FU_NUM)] fu_writeback_stall = i_wb_stall;
    wire[`WDEF(FU_NUM)] fu_regfile_stall = 0;//dont care

    // internal back to back bypass
    wire[`WDEF(FU_NUM)] internal_bypass_wb_vld;
    iprIdx_t internal_bypass_iprdIdx[FU_NUM];
    wire[`XDEF] internal_bypass_data[FU_NUM];

    imm_t s1_irob_imm[`ALU_NUM];

    always_ff @( posedge clk ) begin
        s1_irob_imm <= i_imm_data;
    end

/****************************************************************************************************/
// IQ0: 1x(alu+scu) + 1x(alu)
/****************************************************************************************************/
    wire[`WDEF(INPUT_NUM)] IQ0_has_selected;
    intDQEntry_t IQ0_selected_info[INPUT_NUM];
    wire[`WDEF(`NUMSRCS_INT)] IQ0_enq_iprs_rdy[INPUT_NUM];
    reorder
    #(
        .dtype ( intDQEntry_t ),
        .NUM   ( 4   )
    )
    u_reorder_0(
        .i_data_vld      ( select_toIQ0      ),
        .i_datas         ( i_disp_info       ),
        .o_data_vld      ( IQ0_has_selected  ),
        .o_reorder_datas ( IQ0_selected_info )
    );
    reorder
    #(
        .dtype ( logic[`WDEF(`NUMSRCS_INT)] ),
        .NUM   ( 4   )
    )
    u_reorder_1(
        .i_data_vld      ( select_toIQ0   ),
        .i_datas         ( i_enq_iprs_rdy ),
        .o_reorder_datas ( IQ0_enq_iprs_rdy   )
    );

    wire[`WDEF(2)] IQ0_inst_vld;
    wire[`WDEF($clog2(`IQ0_SIZE))] IQ0_inst_iqIdx[2];
    exeInfo_t IQ0_inst_info[2];

    wire[`WDEF(2)] IQ0_issue_finished;
    wire[`WDEF(2)] IQ0_issue_failed;
    wire[`WDEF($clog2(16))] IQ0_issue_iqIdx[2];

    // IQ0 external wakeup from IQ1(2xalu+2xbru)
    wire[`WDEF(2)] IQ0_ext_wake_vld = i_ext_wake_vec;
    iprIdx_t IQ0_ext_wake_rdIdx[2] = i_ext_wake_rdIdx;

    issueQue
    #(
        .DEPTH              ( `IQ0_SIZE    ),
        .INOUTPORT_NUM      ( 2     ),
        .EXTERNAL_WAKEUPNUM ( 2     ),
        .WBPORT_NUM         ( FU_NUM + EXTERNAL_WRITEBACK     ),
        .INTERNAL_WAKEUP    ( 1     ),
        .SINGLEEXE          ( 1     )
    )
    u_issueQue_0(
        .clk                   ( clk ),
        .rst                   ( rst ),
        .i_stall               ( 0 ),

        .o_can_enq             ( IQ0_ready ),
        .i_enq_req             ( IQ0_has_selected[1:0] ),
        .i_enq_exeInfo         ( {IQ0_selected_info[0], IQ0_selected_info[1]} ),
        .i_enq_iprs_rdy        ( {IQ0_enq_iprs_rdy[0], IQ0_enq_iprs_rdy[1]} ),

        .o_can_issue           ( IQ0_inst_vld   ),
        .o_issue_idx           ( IQ0_inst_iqIdx ),
        .o_issue_exeInfo       ( IQ0_inst_info  ),

        .i_issue_finished_vec  ( IQ0_issue_finished ),
        .i_issue_replay_vec    ( IQ0_issue_failed   ),
        .i_feedback_idx        ( IQ0_issue_iqIdx    ),

        .o_export_wakeup_vld   (    ),
        .o_export_wakeup_rdIdx (    ),

        .i_ext_wakeup_vld      ( IQ0_ext_wake_vld  ),
        .i_ext_wakeup_rdIdx    ( IQ0_ext_wake_rdIdx   ),

        .i_wb_vld              ( global_wb_vld   ),
        .i_wb_rdIdx            ( global_wb_rdIdx   )
    );


    generate
        for(i=0;i<`NUMSRCS_INT;i=i+1) begin : gen_for
            assign o_iprs_idx[0][i] = IQ0_inst_info[0].iprs_idx[i];
            assign o_iprs_idx[1][i] = IQ0_inst_info[1].iprs_idx[i];
        end
    endgenerate

    assign o_immB_idx[0] = IQ0_inst_info[0].irob_idx;
    assign o_immB_idx[1] = IQ0_inst_info[1].irob_idx;

    reg[`WDEF(2)] s1_IQ0_inst_vld;
    reg[`WDEF($clog2(`IQ0_SIZE))] s1_IQ0_inst_iqIdx[2];

    iprIdx_t s1_IQ0_iprs_idx[2][`NUMSRCS_INT];
    exeInfo_t s1_IQ0_inst_info[2];
    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            s1_IQ0_inst_vld <= 0;
        end
        else begin
            // s0: read regfile
            // s1: bypass
            s1_IQ0_inst_vld <= IQ0_inst_vld;
            for (fa=0;fa<`NUMSRCS_INT;fa=fa+1) begin
                s1_IQ0_iprs_idx[0][fa] <= IQ0_inst_info[0].iprs_idx[fa];
                s1_IQ0_iprs_idx[1][fa] <= IQ0_inst_info[1].iprs_idx[fa];
            end
            s1_IQ0_inst_iqIdx <= IQ0_inst_iqIdx;
            s1_IQ0_inst_info <= IQ0_inst_info;
        end
    end

/****************************************************************************************************/
// alu0
/****************************************************************************************************/
generate
if (1) begin: gen_intBlock_IQ0_alu0
    localparam int IQ0_fuID = 0;
    localparam int intBlock_fuID = 0;
    localparam int global_fuID = 0;
    // when one instruction was selected
    // there are 2 stage to process
    // s0: send request to regfile
    // s1: read data and check bypass, check inst can issue and deq from issueQue
    wire fu_stall;
    wire[`WDEF(`NUMSRCS_INT)] alu_bypass_vld;
    wire[`XDEF] alu_bypass_data[`NUMSRCS_INT];

    assign IQ0_issue_finished[IQ0_fuID] = s1_IQ0_inst_vld[IQ0_fuID] && ((i_iprs_ready[intBlock_fuID] | alu_bypass_vld | {s1_IQ0_inst_info[IQ0_fuID].use_imm, 1'b1}) == 2'b11);
    assign IQ0_issue_failed[IQ0_fuID] = s1_IQ0_inst_vld[IQ0_fuID] && (!IQ0_issue_finished[IQ0_fuID]);
    assign IQ0_issue_iqIdx[IQ0_fuID] = s1_IQ0_inst_iqIdx[IQ0_fuID];

    bypass_sel
    #(
        // why need to multiply by two
        // one from will writeback bypass
        // one from writeback take a pat
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src0(
        .i_src_vld     ( global_bypass_vld     ),
        .i_src_idx     ( global_bypass_rdIdx     ),
        .i_src_data    ( global_bypass_data    ),
        .i_target_idx  ( s1_IQ0_inst_info[IQ0_fuID].iprs_idx[0]  ),
        .o_target_vld  ( alu_bypass_vld[0]  ),
        .o_target_data ( alu_bypass_data[0] )
    );
    bypass_sel
    #(
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src1(
        .i_src_vld     ( global_bypass_vld      ),
        .i_src_idx     ( global_bypass_rdIdx  ),
        .i_src_data    ( global_bypass_data     ),
        .i_target_idx  ( s1_IQ0_inst_info[IQ0_fuID].iprs_idx[1] ),
        .o_target_vld  ( alu_bypass_vld[1]        ),
        .o_target_data ( alu_bypass_data[1]       )
    );

    fuInfo_t fu_info;
    assign fu_info = '{
        ftq_idx : s1_IQ0_inst_info[IQ0_fuID].ftq_idx,
        rob_idx : s1_IQ0_inst_info[IQ0_fuID].rob_idx,
        irob_idx : s1_IQ0_inst_info[IQ0_fuID].irob_idx,
        use_imm : s1_IQ0_inst_info[IQ0_fuID].use_imm,
        rd_wen : s1_IQ0_inst_info[IQ0_fuID].rd_wen,
        iprd_idx : s1_IQ0_inst_info[IQ0_fuID].iprd_idx,
        srcs : {
            alu_bypass_vld[0] ? alu_bypass_data[0] : i_iprs_data[intBlock_fuID][0],
            s1_IQ0_inst_info[IQ0_fuID].use_imm ? s1_irob_imm[intBlock_fuID] : (alu_bypass_vld[1] ? alu_bypass_data[1] : i_iprs_data[intBlock_fuID][1])
        },// need bypass
        issueQue_id : s1_IQ0_inst_info[IQ0_fuID].issueQue_id,
        micOp : s1_IQ0_inst_info[IQ0_fuID].micOp_type
    };

    //fu0
    alu u_alu(
        .clk               ( clk                ),
        .rst               ( rst                ),

        .o_fu_stall        ( fu_stall         ),
        .i_vld             ( s1_IQ0_inst_vld[IQ0_fuID] ),
        .i_fuInfo          ( fu_info          ),

        .o_willwrite_vld   ( internal_bypass_wb_vld[intBlock_fuID]  ),
        .o_willwrite_rdIdx ( internal_bypass_iprdIdx[intBlock_fuID] ),
        .o_willwrite_data  ( internal_bypass_data[intBlock_fuID]    ),

        .i_wb_stall        ( i_wb_stall[intBlock_fuID]     ),
        .o_fu_finished          ( fu_finished[intBlock_fuID]         ),
        .o_comwbInfo          ( comwbInfo[intBlock_fuID]         )
    );
end
endgenerate
/****************************************************************************************************/
// alu1
/****************************************************************************************************/
generate
if (1) begin : gen_intBlock_IQ0_alu1
    localparam int IQ0_fuID = 1;
    localparam int intBlock_fuID = 1;
    localparam int global_fuID = 1;

    wire fu_stall;
    wire[`WDEF(`NUMSRCS_INT)] alu_bypass_vld;
    wire[`XDEF] alu_bypass_data[`NUMSRCS_INT];

    assign IQ0_issue_finished[IQ0_fuID] = s1_IQ0_inst_vld[IQ0_fuID] && ((i_iprs_ready[intBlock_fuID] | alu_bypass_vld | {s1_IQ0_inst_info[IQ0_fuID].use_imm, 1'b1}) == 2'b11);
    assign IQ0_issue_failed[IQ0_fuID] = s1_IQ0_inst_vld[IQ0_fuID] && (!IQ0_issue_finished[IQ0_fuID]);
    assign IQ0_issue_iqIdx[IQ0_fuID] = s1_IQ0_inst_iqIdx[IQ0_fuID];

    bypass_sel
    #(
        // why need to multiply by two
        // one from will writeback bypass
        // one from writeback take a pat
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src0(
        .i_src_vld     ( global_bypass_vld     ),
        .i_src_idx     ( global_bypass_rdIdx     ),
        .i_src_data    ( global_bypass_data    ),
        .i_target_idx  ( s1_IQ0_inst_info[IQ0_fuID].iprs_idx[0]  ),
        .o_target_vld  ( alu_bypass_vld[0]  ),
        .o_target_data ( alu_bypass_data[0] )
    );
    bypass_sel
    #(
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src1(
        .i_src_vld     ( global_bypass_vld      ),
        .i_src_idx     ( global_bypass_rdIdx  ),
        .i_src_data    ( global_bypass_data     ),
        .i_target_idx  ( s1_IQ0_inst_info[IQ0_fuID].iprs_idx[1] ),
        .o_target_vld  ( alu_bypass_vld[1]        ),
        .o_target_data ( alu_bypass_data[1]       )
    );

    fuInfo_t fu_info;
    assign fu_info = '{
        ftq_idx : s1_IQ0_inst_info[IQ0_fuID].ftq_idx,
        rob_idx : s1_IQ0_inst_info[IQ0_fuID].rob_idx,
        irob_idx : s1_IQ0_inst_info[IQ0_fuID].irob_idx,
        use_imm : s1_IQ0_inst_info[IQ0_fuID].use_imm,
        rd_wen : s1_IQ0_inst_info[IQ0_fuID].rd_wen,
        iprd_idx : s1_IQ0_inst_info[IQ0_fuID].iprd_idx,
        srcs : {// FIXME: regfile read data is zero
            alu_bypass_vld[0] ? alu_bypass_data[0] : i_iprs_data[intBlock_fuID][0],
            s1_IQ0_inst_info[IQ0_fuID].use_imm ? s1_irob_imm[intBlock_fuID] : (alu_bypass_vld[1] ? alu_bypass_data[1] : i_iprs_data[intBlock_fuID][1])
        },// need bypass
        issueQue_id : s1_IQ0_inst_info[IQ0_fuID].issueQue_id,
        micOp : s1_IQ0_inst_info[IQ0_fuID].micOp_type
    };

    //fu1
    alu u_alu(
        .clk               ( clk                ),
        .rst               ( rst                ),

        .o_fu_stall        ( fu_stall         ),
        .i_vld             ( s1_IQ0_inst_vld[IQ0_fuID] ),
        .i_fuInfo          ( fu_info          ),

        .o_willwrite_vld   ( internal_bypass_wb_vld[intBlock_fuID]  ),
        .o_willwrite_rdIdx ( internal_bypass_iprdIdx[intBlock_fuID] ),
        .o_willwrite_data  ( internal_bypass_data[intBlock_fuID]    ),

        .i_wb_stall        ( i_wb_stall[intBlock_fuID]     ),
        .o_fu_finished          ( fu_finished[intBlock_fuID]         ),
        .o_comwbInfo          ( comwbInfo[intBlock_fuID]         )
    );
end
endgenerate
/****************************************************************************************************/
// IQ1: 2x(alu+bru)
/****************************************************************************************************/
    wire[`WDEF(INPUT_NUM)] IQ1_has_selected;
    intDQEntry_t IQ1_selected_info[INPUT_NUM];
    wire[`WDEF(`NUMSRCS_INT)] IQ1_enq_iprs_rdy[INPUT_NUM];
    reorder
    #(
        .dtype ( intDQEntry_t ),
        .NUM   ( 4   )
    )
    u_reorder_2(
        .i_data_vld      ( select_toIQ1      ),
        .i_datas         ( i_disp_info       ),
        .o_data_vld      ( IQ1_has_selected  ),
        .o_reorder_datas ( IQ1_selected_info )
    );
    reorder
    #(
        .dtype ( logic[`WDEF(`NUMSRCS_INT)] ),
        .NUM   ( 4   )
    )
    u_reorder_3(
        .i_data_vld      ( select_toIQ1   ),
        .i_datas         ( i_enq_iprs_rdy ),
        .o_reorder_datas ( IQ1_enq_iprs_rdy   )
    );

    wire[`WDEF(2)] IQ1_inst_vld;
    wire[`WDEF($clog2(`IQ1_SIZE))] IQ1_inst_iqIdx[2];
    exeInfo_t IQ1_inst_info[2];

    wire[`WDEF(2)] IQ1_issue_finished;
    wire[`WDEF(2)] IQ1_issue_failed;
    wire[`WDEF($clog2(16))] IQ1_issue_iqIdx[2];

    // IQ1 external wakeup from IQ1(2xalu+2xbru)
    wire[`WDEF(2)] IQ1_ext_wake_vld = i_ext_wake_vec;
    iprIdx_t IQ1_ext_wake_rdIdx[2] = i_ext_wake_rdIdx;

    issueQue
    #(
        .DEPTH              ( `IQ1_SIZE    ),
        .INOUTPORT_NUM      ( 2     ),
        .EXTERNAL_WAKEUPNUM ( 2     ),
        .WBPORT_NUM         ( FU_NUM + EXTERNAL_WRITEBACK     ),
        .INTERNAL_WAKEUP    ( 1     ),
        .SINGLEEXE          ( 1     )
    )
    u_issueQue_1(
        .clk                   ( clk ),
        .rst                   ( rst ),
        .i_stall               ( 0 ),

        .o_can_enq             ( IQ1_ready ),
        .i_enq_req             ( IQ1_has_selected[1:0] ),
        .i_enq_exeInfo         ( {IQ1_selected_info[0], IQ1_selected_info[1]} ),
        .i_enq_iprs_rdy        ( {IQ1_enq_iprs_rdy[0], IQ1_enq_iprs_rdy[1]} ),

        .o_can_issue           ( IQ1_inst_vld   ),
        .o_issue_idx           ( IQ1_inst_iqIdx ),
        .o_issue_exeInfo       ( IQ1_inst_info  ),

        .i_issue_finished_vec  ( IQ1_issue_finished ),
        .i_issue_replay_vec    ( IQ1_issue_failed   ),
        .i_feedback_idx        ( IQ1_issue_iqIdx    ),

        .o_export_wakeup_vld   (    ),
        .o_export_wakeup_rdIdx (    ),

        .i_ext_wakeup_vld      ( IQ1_ext_wake_vld  ),
        .i_ext_wakeup_rdIdx    ( IQ1_ext_wake_rdIdx   ),

        .i_wb_vld              ( global_wb_vld   ),
        .i_wb_rdIdx            ( global_wb_rdIdx   )
    );


    generate
        for(i=0;i<`NUMSRCS_INT;i=i+1) begin : gen_for
            assign o_iprs_idx[2][i] = IQ1_inst_info[0].iprs_idx[i];
            assign o_iprs_idx[3][i] = IQ1_inst_info[1].iprs_idx[i];
        end
    endgenerate

    assign o_immB_idx[2] = IQ1_inst_info[0].irob_idx;
    assign o_immB_idx[3] = IQ1_inst_info[1].irob_idx;

    reg[`WDEF(2)] s1_IQ1_inst_vld;
    reg[`WDEF($clog2(`IQ1_SIZE))] s1_IQ1_inst_iqIdx[2];
    iprIdx_t s1_IQ1_iprs_idx[2][`NUMSRCS_INT];
    exeInfo_t s1_IQ1_inst_info[2];
    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            s1_IQ1_inst_vld <= 0;
        end
        else begin
            // s0: read regfile
            // s1: bypass
            s1_IQ1_inst_vld <= IQ1_inst_vld;
            for (fa=0;fa<`NUMSRCS_INT;fa=fa+1) begin
                s1_IQ1_iprs_idx[0][fa] <= IQ1_inst_info[0].iprs_idx[fa];
                s1_IQ1_iprs_idx[1][fa] <= IQ1_inst_info[1].iprs_idx[fa];
            end
            s1_IQ1_inst_iqIdx <= IQ1_inst_iqIdx;
            s1_IQ1_inst_info <= IQ1_inst_info;
        end
    end

/****************************************************************************************************/
// alu2
/****************************************************************************************************/
generate
if (1) begin: gen_intBlock_IQ1_alu2
    localparam int IQ1_fuID = 0;
    localparam int intBlock_fuID = 2;
    localparam int global_fuID = 2;
    // when one instruction was selected
    // there are 2 stage to process
    // s0: send request to regfile
    // s1: read data and check bypass, check inst can issue and deq from issueQue
    wire fu_stall;
    wire[`WDEF(`NUMSRCS_INT)] alu_bypass_vld;
    wire[`XDEF] alu_bypass_data[`NUMSRCS_INT];

    assign IQ1_issue_finished[IQ1_fuID] = s1_IQ1_inst_vld[IQ1_fuID] && ((i_iprs_ready[intBlock_fuID] | alu_bypass_vld | {s1_IQ1_inst_info[IQ1_fuID].use_imm, 1'b1}) == 2'b11);
    assign IQ1_issue_failed[IQ1_fuID] = s1_IQ1_inst_vld[IQ1_fuID] && (!IQ1_issue_finished[IQ1_fuID]);
    assign IQ1_issue_iqIdx[IQ1_fuID] = s1_IQ1_inst_iqIdx[IQ1_fuID];

    bypass_sel
    #(
        // why need to multiply by two
        // one from will writeback bypass
        // one from writeback take a pat
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src0(
        .i_src_vld     ( global_bypass_vld     ),
        .i_src_idx     ( global_bypass_rdIdx     ),
        .i_src_data    ( global_bypass_data    ),
        .i_target_idx  ( s1_IQ1_inst_info[IQ1_fuID].iprs_idx[0]  ),
        .o_target_vld  ( alu_bypass_vld[0]  ),
        .o_target_data ( alu_bypass_data[0] )
    );
    bypass_sel
    #(
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src1(
        .i_src_vld     ( global_bypass_vld      ),
        .i_src_idx     ( global_bypass_rdIdx  ),
        .i_src_data    ( global_bypass_data     ),
        .i_target_idx  ( s1_IQ1_inst_info[IQ1_fuID].iprs_idx[1] ),
        .o_target_vld  ( alu_bypass_vld[1]        ),
        .o_target_data ( alu_bypass_data[1]       )
    );

    fuInfo_t fu_info;
    assign fu_info = '{
        ftq_idx : s1_IQ1_inst_info[IQ1_fuID].ftq_idx,
        rob_idx : s1_IQ1_inst_info[IQ1_fuID].rob_idx,
        irob_idx : s1_IQ1_inst_info[IQ1_fuID].irob_idx,
        use_imm : s1_IQ1_inst_info[IQ1_fuID].use_imm,
        rd_wen : s1_IQ1_inst_info[IQ1_fuID].rd_wen,
        iprd_idx : s1_IQ1_inst_info[IQ1_fuID].iprd_idx,
        srcs : {
            alu_bypass_vld[0] ? alu_bypass_data[0] : i_iprs_data[intBlock_fuID][0],
            s1_IQ1_inst_info[IQ1_fuID].use_imm ? s1_irob_imm[intBlock_fuID] : (alu_bypass_vld[1] ? alu_bypass_data[1] : i_iprs_data[intBlock_fuID][1])
        },// need bypass
        issueQue_id : s1_IQ1_inst_info[IQ1_fuID].issueQue_id,
        micOp : s1_IQ1_inst_info[IQ1_fuID].micOp_type
    };

    //fu2
    alu u_alu(
        .clk               ( clk                ),
        .rst               ( rst                ),

        .o_fu_stall        ( fu_stall         ),
        .i_vld             ( s1_IQ1_inst_vld[IQ1_fuID] ),
        .i_fuInfo          ( fu_info          ),

        .o_willwrite_vld   ( internal_bypass_wb_vld[intBlock_fuID]  ),
        .o_willwrite_rdIdx ( internal_bypass_iprdIdx[intBlock_fuID] ),
        .o_willwrite_data  ( internal_bypass_data[intBlock_fuID]    ),

        .i_wb_stall        ( i_wb_stall[intBlock_fuID]     ),
        .o_fu_finished          ( fu_finished[intBlock_fuID]         ),
        .o_comwbInfo          ( comwbInfo[intBlock_fuID]         )
    );
end
endgenerate
/****************************************************************************************************/
// alu3
/****************************************************************************************************/
generate
if (1) begin : gen_intBlock_IQ1_alu3
    localparam int IQ1_fuID = 1;
    localparam int intBlock_fuID = 3;
    localparam int global_fuID = 3;

    wire fu_stall;
    wire[`WDEF(`NUMSRCS_INT)] alu_bypass_vld;
    wire[`XDEF] alu_bypass_data[`NUMSRCS_INT];

    assign IQ1_issue_finished[IQ1_fuID] = s1_IQ1_inst_vld[IQ1_fuID] && ((i_iprs_ready[intBlock_fuID] | alu_bypass_vld | {s1_IQ1_inst_info[IQ1_fuID].use_imm, 1'b1}) == 2'b11);
    assign IQ1_issue_failed[IQ1_fuID] = s1_IQ1_inst_vld[IQ1_fuID] && (!IQ1_issue_finished[IQ1_fuID]);
    assign IQ1_issue_iqIdx[IQ1_fuID] = s1_IQ1_inst_iqIdx[IQ1_fuID];

    bypass_sel
    #(
        // why need to multiply by two
        // one from will writeback bypass
        // one from writeback take a pat
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src0(
        .i_src_vld     ( global_bypass_vld     ),
        .i_src_idx     ( global_bypass_rdIdx     ),
        .i_src_data    ( global_bypass_data    ),
        .i_target_idx  ( s1_IQ1_inst_info[IQ1_fuID].iprs_idx[0]  ),
        .o_target_vld  ( alu_bypass_vld[0]  ),
        .o_target_data ( alu_bypass_data[0] )
    );
    bypass_sel
    #(
        .WIDTH ( FU_NUM*3 + EXTERNAL_WRITEBACK*2 )
    )
    u_bypass_sel_0_src1(
        .i_src_vld     ( global_bypass_vld      ),
        .i_src_idx     ( global_bypass_rdIdx  ),
        .i_src_data    ( global_bypass_data     ),
        .i_target_idx  ( s1_IQ1_inst_info[IQ1_fuID].iprs_idx[1] ),
        .o_target_vld  ( alu_bypass_vld[1]        ),
        .o_target_data ( alu_bypass_data[1]       )
    );

    fuInfo_t fu_info;
    assign fu_info = '{
        ftq_idx : s1_IQ1_inst_info[IQ1_fuID].ftq_idx,
        rob_idx : s1_IQ1_inst_info[IQ1_fuID].rob_idx,
        irob_idx : s1_IQ1_inst_info[IQ1_fuID].irob_idx,
        use_imm : s1_IQ1_inst_info[IQ1_fuID].use_imm,
        rd_wen : s1_IQ1_inst_info[IQ1_fuID].rd_wen,
        iprd_idx : s1_IQ1_inst_info[IQ1_fuID].iprd_idx,
        srcs : {// FIXME: regfile read data is zero
            alu_bypass_vld[0] ? alu_bypass_data[0] : i_iprs_data[intBlock_fuID][0],
            s1_IQ1_inst_info[IQ1_fuID].use_imm ? s1_irob_imm[intBlock_fuID] : (alu_bypass_vld[1] ? alu_bypass_data[1] : i_iprs_data[intBlock_fuID][1])
        },// need bypass
        issueQue_id : s1_IQ1_inst_info[IQ1_fuID].issueQue_id,
        micOp : s1_IQ1_inst_info[IQ1_fuID].micOp_type
    };

    //fu1
    alu u_alu(
        .clk               ( clk                ),
        .rst               ( rst                ),

        .o_fu_stall        ( fu_stall         ),
        .i_vld             ( s1_IQ1_inst_vld[IQ1_fuID] ),
        .i_fuInfo          ( fu_info          ),

        .o_willwrite_vld   ( internal_bypass_wb_vld[intBlock_fuID]  ),
        .o_willwrite_rdIdx ( internal_bypass_iprdIdx[intBlock_fuID] ),
        .o_willwrite_data  ( internal_bypass_data[intBlock_fuID]    ),

        .i_wb_stall        ( i_wb_stall[intBlock_fuID]     ),
        .o_fu_finished          ( fu_finished[intBlock_fuID]         ),
        .o_comwbInfo          ( comwbInfo[intBlock_fuID]         )
    );
end
endgenerate



/****************************************************************************************************/
// IQ2: 2x(mdu)
/****************************************************************************************************/








/****************************************************************************************************/
// others
/****************************************************************************************************/
    assign fu_finished[FU_NUM-1:4] = 0;
    assign o_comwbInfo = comwbInfo;
    assign o_fu_finished = fu_finished;

    assign o_branchWB_vld = 0;
    assign o_exceptwb_vld = 0;


    reg[`WDEF(FU_NUM)] pat1_wb_vld;
    iprIdx_t pat1_wb_iprdIdx[FU_NUM];
    reg[`XDEF] pat1_wb_data[FU_NUM];
    reg[`WDEF(EXTERNAL_WRITEBACK)] pat1_extwb_vld;
    iprIdx_t pat1_extwb_iprdIdx[EXTERNAL_WRITEBACK];
    reg[`XDEF] pat1_extwb_data[EXTERNAL_WRITEBACK];
    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            pat1_wb_vld <= 0;
        end
        else begin
            for (fa=0;fa<FU_NUM;fa=fa+1) begin
                pat1_wb_vld[fa] <= fu_finished[fa] && comwbInfo[fa].rd_wen;
                pat1_wb_iprdIdx[fa] <= comwbInfo[fa].iprd_idx;
                pat1_wb_data[fa] <= comwbInfo[fa].result;
            end
            pat1_extwb_vld <= i_ext_wb_vec;
            pat1_extwb_iprdIdx <= i_ext_wb_rdIdx;
            pat1_extwb_data <= i_ext_wb_data;
        end
    end

    generate
        for(i=0; i<FU_NUM * 3 + EXTERNAL_WRITEBACK * 2; i=i+1) begin : gen_for
            if (i < FU_NUM) begin : gen_if
                assign global_bypass_vld[i] = internal_bypass_wb_vld[i] && (i < 4);
                assign global_bypass_rdIdx[i] = internal_bypass_iprdIdx[i];
                assign global_bypass_data[i] = internal_bypass_data[i];
            end
            else if (i < FU_NUM*2) begin : gen_elif
                // internal wb to s1 bypass
                assign global_bypass_vld[i] = 0;// fu_finished[i - FU_NUM] && comwbInfo[i - FU_NUM].rd_wen;
                assign global_bypass_rdIdx[i] = comwbInfo[i - FU_NUM].iprd_idx;
                assign global_bypass_data[i] = comwbInfo[i - FU_NUM].result;
            end
            else if (i < FU_NUM*3) begin : gen_elif
                // internal wb to s0 bypass
                assign global_bypass_vld[i] = 0;// pat1_wb_vld[i - FU_NUM*2];
                assign global_bypass_rdIdx[i] = pat1_wb_iprdIdx[i - FU_NUM*2];
                assign global_bypass_data[i] = pat1_wb_data[i - FU_NUM*2];
            end
            else if (i < FU_NUM*3 + EXTERNAL_WRITEBACK) begin : gen_elif
                // external wb to s1 bypass
                assign global_bypass_vld[i] = 0;// i_ext_wb_vec[i - FU_NUM*3];
                assign global_bypass_rdIdx[i] = i_ext_wb_rdIdx[i - FU_NUM*3];
                assign global_bypass_data[i] = i_ext_wb_data[i - FU_NUM*3];
            end
            else if (i < FU_NUM*3 + EXTERNAL_WRITEBACK*2) begin : gen_elif
                // external wb to s0 bypass
                assign global_bypass_vld[i] = 0;// pat1_extwb_vld[i - FU_NUM*3 + EXTERNAL_WRITEBACK];
                assign global_bypass_rdIdx[i] = pat1_extwb_iprdIdx[i - FU_NUM*3 - EXTERNAL_WRITEBACK];
                assign global_bypass_data[i] = pat1_extwb_data[i - FU_NUM*3 - EXTERNAL_WRITEBACK];
            end
        end

        for (i=0;i<FU_NUM + EXTERNAL_WRITEBACK;i=i+1) begin : gen_for
            if (i < FU_NUM) begin : gen_if
                assign global_wb_vld[i] = fu_finished[i] && comwbInfo[i].rd_wen && (i < 4);
                assign global_wb_rdIdx[i] = comwbInfo[i].iprd_idx;
            end
            else begin: gen_else
                assign global_wb_vld[i] = i_ext_wb_vec[i - FU_NUM];
                assign global_wb_rdIdx[i] = i_ext_wb_rdIdx[i - FU_NUM];
            end
        end
        for (i=0;i<FU_NUM + EXTERNAL_WAKEUP;i=i+1) begin : gen_for
            if (i < FU_NUM) begin : gen_if
                assign global_wake_vld[i] = 0;
                assign global_wake_rdIdx[i] = 0;
            end
            else begin: gen_else
                assign global_wake_vld[i] = i_ext_wake_vec[i - FU_NUM];
                assign global_wake_rdIdx[i] = i_ext_wake_rdIdx[i - FU_NUM];
            end
        end
    endgenerate






endmodule


