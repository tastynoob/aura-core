







// IQ0: load
// IQ1: store data
// IQ2: store addr


module memBlock #(
    parameter int INPUT_NUM = `ISSUE_WIDTH,
    parameter int EXTERNAL_WRITEBACK = 6,// 2 mdu + 4alu
    parameter int EXTERNAL_WAKEUP = 4,// external wake up sources ( 4alu )
    parameter int FU_NUM = 6
) (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from dispatch
    output wire[`WDEF(INPUT_NUM)] o_disp_vld,
    input wire[`WDEF(INPUT_NUM)] i_disp_req,
    input memDQEntry_t i_disp_info[INPUT_NUM],
    input wire[`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INPUT_NUM],
    input wire i_enq_memdep_rdy[INPUT_NUM],

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
    // read ftqOffste (to rob)
    output wire[`WDEF($clog2(`ROB_SIZE))] o_read_robIdx[`BRU_NUM],
    input ftqOffset_t i_read_ftqOffset[`BRU_NUM],

    // writeback
    input wire[`WDEF(FU_NUM)] i_wb_stall,
    output wire[`WDEF(FU_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[FU_NUM],
    output wire[`WDEF(`BRU_NUM)] o_branchWB_vld,
    output branchwbInfo_t o_branchwb_info[`BRU_NUM],
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

    wire[`WDEF(INPUT_NUM)] select_ldu, select_stu;
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(INPUT_NUM)] select_total;
    wire[`WDEF(INPUT_NUM)] select_toIQ0, select_toIQ1;

    generate
        for(i=0;i<INPUT_NUM;i=i+1) begin : gen_for
            assign select_ldu[i] = i_disp_req[i] && (i_disp_info[i].issueQue_id == `LDUIQ_ID);
            assign select_stu[i] = i_disp_req[i] && (i_disp_info[i].issueQue_id == `STUIQ_ID);

            if (i==0) begin : gen_if
                assign select_total[i] = select_toIQ0[i] || select_toIQ1[i];
            end
            else begin : gen_else
                assign select_total[i] = (select_toIQ0[i] || select_toIQ1[i]) && select_total[i-1];
            end

            if (i == 0) begin : gen_if
                assign select_toIQ0[i] = IQ0_ready && select_ldu[i];
                assign select_toIQ1[i] = IQ1_ready && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i])));
            end
            else if (i < 2) begin : gen_elif
                assign select_toIQ0[i] = IQ0_ready && select_ldu[i] && select_total[i-1];
                assign select_toIQ1[i] = IQ1_ready && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i]))) && select_total[i-1];
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
                wire[`SDEF(i)] IQ1_has_selected_num;
                count_one
                #(
                    .WIDTH ( i )
                )
                u_count_one_1(
                    .i_a   ( select_toIQ1[i-1:0]   ),
                    .o_sum ( IQ1_has_selected_num )
                );

                assign select_toIQ0[i] = IQ0_ready && (IQ0_has_selected_num < 2) && select_ldu[i] && select_total[i-1];
                assign select_toIQ1[i] = IQ1_ready && (IQ1_has_selected_num < 2) && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i]))) && select_total[i-1];
            end
        end
    endgenerate

    `ASSERT(funcs::count_one(select_toIQ0) <= 2);
    `ASSERT(funcs::count_one(select_toIQ1) <= 2);
    `ASSERT((select_toIQ0 & select_toIQ1) == 0);
    `ORDER_CHECK((select_toIQ0 | select_toIQ1));

    assign o_disp_vld = select_total;

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

    wire[`WDEF(2)] IQ0_export_wake_vld;
    iprIdx_t IQ0_export_wake_rdIdx[2];

    wire[`WDEF(2)] IQ1_export_wake_vld;
    iprIdx_t IQ1_export_wake_rdIdx[2];



/****************************************************************************************************/
// load unit
//
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
    intExeInfo_t IQ0_inst_info[2];

    wire[`WDEF(2)] IQ0_issue_finished;
    wire[`WDEF(2)] IQ0_issue_failed;
    wire[`WDEF($clog2(16))] IQ0_issue_iqIdx[2];

    // IQ0 external wakeup from IQ1(2xalu+2xbru)
    wire[`WDEF(2)] IQ0_ext_wake_vld = IQ1_export_wake_vld;
    iprIdx_t IQ0_ext_wake_rdIdx[2];
    assign IQ0_ext_wake_rdIdx = IQ1_export_wake_rdIdx;

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
        .rst                   ( rst || i_squash_vld ),
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

        .o_export_wakeup_vld   ( IQ0_export_wake_vld   ),
        .o_export_wakeup_rdIdx ( IQ0_export_wake_rdIdx   ),

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
    intExeInfo_t s1_IQ0_inst_info[2];
    always_ff @( posedge clk ) begin
        int fa;
        if (rst || i_squash_vld) begin
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












endmodule
