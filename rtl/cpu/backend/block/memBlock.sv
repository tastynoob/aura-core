// IQ0/2: load
// IQ1.1/3: store data
// IQ1.2/3: store addr


module memBlock #(
    parameter int INPUT_NUM = `MEMDQ_DISP_WID,
    parameter int FU_NUM = `LDU_NUM + `STU_NUM // 2ld + 2sta/std
) (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from dispatch
    disp_if.s if_disp,
    input wire[`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INPUT_NUM],
    input wire i_enq_memdep_rdy[INPUT_NUM],

    // regfile read
    output iprIdx_t o_iprs_idx[`LDU_NUM + `STU_NUM*2],// read regfile
    input wire i_iprs_ready[`LDU_NUM + `STU_NUM*2],// ready or not
    input wire[`XDEF] i_iprs_data[`LDU_NUM + `STU_NUM*2],

    // immBuffer read
    output irobIdx_t o_immB_idx[FU_NUM],
    input imm_t i_imm_data[FU_NUM],

    // writeback
    input wire[`WDEF(`LDU_NUM)] i_wb_stall,
    output wire[`WDEF(FU_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[FU_NUM],

    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    loadwake_if.m if_loadwake,

    // export bypass data
    output wire[`WDEF(`MEM_WBPORT_NUM)] o_exp_bp_vec,
    output iprIdx_t o_exp_bp_iprd[`MEM_WBPORT_NUM],
    output wire[`XDEF] o_exp_bp_data[`MEM_WBPORT_NUM],

    // external specwake
    input wire[`WDEF(`INT_SWAKE_WIDTH)] i_ext_swk_vec,
    input iprIdx_t i_ext_swk_iprd[`INT_SWAKE_WIDTH],

    // global bypass data
    input wire[`WDEF(`BYPASS_WIDTH)] i_glob_bp_vec,
    input iprIdx_t i_glob_bp_iprd[`BYPASS_WIDTH],
    input wire[`XDEF] i_glob_bp_data[`BYPASS_WIDTH]
);
    assign if_disp.mem_rdy = 0;
    assign if_loadwake.wk = 0;
    assign o_exp_bp_vec = 0;
    assign o_exceptwb_vld = 0;
    assign o_fu_finished = 0;

//     genvar i;

//     microOp_t toLD_exeInfo[2];
//     microOp_t toSTA_exeInfo[2];
//     microOp_t toSTD_exeInfo[2];

//     wire[`WDEF(FU_NUM)] fu_finished;
//     comwbInfo_t comwbInfo[FU_NUM];

//     wire IQ0_ready, IQ1_ready;

//     wire[`WDEF(INPUT_NUM)] select_ldu, select_stu;
//     /* verilator lint_off UNOPTFLAT */
//     wire[`WDEF(INPUT_NUM)] select_total;
//     wire[`WDEF(INPUT_NUM)] select_toIQ0, select_toIQ1;

//     generate
//         for(i=0;i<INPUT_NUM;i=i+1) begin : gen_for
//             assign select_ldu[i] = i_disp_req[i] && (i_disp_info[i].issueQue_id == `LDUIQ_ID);
//             assign select_stu[i] = i_disp_req[i] && (i_disp_info[i].issueQue_id == `STUIQ_ID);

//             if (i==0) begin : gen_if
//                 assign select_total[i] = select_toIQ0[i] || select_toIQ1[i];
//             end
//             else begin : gen_else
//                 assign select_total[i] = (select_toIQ0[i] || select_toIQ1[i]) && select_total[i-1];
//             end

//             if (i == 0) begin : gen_if
//                 assign select_toIQ0[i] = IQ0_ready && select_ldu[i];
//                 assign select_toIQ1[i] = IQ1_ready && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i])));
//             end
//             else if (i < 2) begin : gen_elif
//                 assign select_toIQ0[i] = IQ0_ready && select_ldu[i] && select_total[i-1];
//                 assign select_toIQ1[i] = IQ1_ready && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i]))) && select_total[i-1];
//             end
//             else begin : gen_else
//                 // IQ0 current has selected
//                 wire[`SDEF(i)] IQ0_has_selected_num;
//                 count_one
//                 #(
//                     .WIDTH ( i )
//                 )
//                 u_count_one_0(
//                     .i_a   ( select_toIQ0[i-1:0]   ),
//                     .o_sum ( IQ0_has_selected_num )
//                 );
//                 // IQ1 current has selected
//                 wire[`SDEF(i)] IQ1_has_selected_num;
//                 count_one
//                 #(
//                     .WIDTH ( i )
//                 )
//                 u_count_one_1(
//                     .i_a   ( select_toIQ1[i-1:0]   ),
//                     .o_sum ( IQ1_has_selected_num )
//                 );

//                 assign select_toIQ0[i] = IQ0_ready && (IQ0_has_selected_num < 2) && select_ldu[i] && select_total[i-1];
//                 assign select_toIQ1[i] = IQ1_ready && (IQ1_has_selected_num < 2) && (select_stu[i] || (select_ldu[i] && (!select_toIQ0[i]))) && select_total[i-1];
//             end
//         end
//     endgenerate

//     `ASSERT(funcs::count_one(select_toIQ0) <= 2);
//     `ASSERT(funcs::count_one(select_toIQ1) <= 2);
//     `ASSERT((select_toIQ0 & select_toIQ1) == 0);
//     `ORDER_CHECK((select_toIQ0 | select_toIQ1));

//     assign o_disp_vld = select_total;

//     // WBPORTS*3 : will writeback + writeback bypass + writeback read regfile bypass
//     // EXTERNAL_WAKEUP*2 : writeback bypass + writeback read regfile bypass
//     wire[`WDEF(WBPORTS * 3 + EXTERNAL_WRITEBACK * 2)] global_bypass_vld;
//     iprIdx_t global_bypass_rdIdx[WBPORTS * 3 + EXTERNAL_WRITEBACK * 2];
//     wire[`XDEF] global_bypass_data[WBPORTS * 3 + EXTERNAL_WRITEBACK * 2];

//     // global writeback (used for wakeup)
//     wire[`WDEF(WBPORTS + EXTERNAL_WRITEBACK)] global_wb_vld;
//     iprIdx_t global_wb_rdIdx[WBPORTS + EXTERNAL_WRITEBACK];

//     // global wakeup (speculative)
//     wire[`WDEF(WBPORTS + EXTERNAL_WAKEUP)] global_wake_vld;
//     iprIdx_t global_wake_rdIdx[WBPORTS + EXTERNAL_WAKEUP];

//     wire[`WDEF(WBPORTS)] fu_writeback_stall = i_wb_stall;
//     wire[`WDEF(FU_NUM)] fu_regfile_stall = 0;//dont care

//     // internal back to back bypass
//     wire[`WDEF(WBPORTS)] internal_bypass_wb_vld;
//     iprIdx_t internal_bypass_iprdIdx[WBPORTS];
//     wire[`XDEF] internal_bypass_data[WBPORTS];

//     imm_t s1_irob_imm[FU_NUM];
//     always_ff @( posedge clk ) begin
//         s1_irob_imm <= i_imm_data;
//     end

//     wire[`WDEF(2)] IQ0_export_wake_vld;
//     iprIdx_t IQ0_export_wake_rdIdx[2];

// /****************************************************************************************************/
// // load IQ
// //
// /****************************************************************************************************/

//     wire[`WDEF(INPUT_NUM)] IQ0_has_selected;
//     microOp_t IQ0_selected_info[INPUT_NUM];
//     wire[`WDEF(`NUMSRCS_INT)] IQ0_enq_iprs_rdy[INPUT_NUM];
//     wire IQ0_enq_memdep_rdy[INPUT_NUM];

//     reorder
//     #(
//         .dtype ( microOp_t ),
//         .NUM   ( 4   )
//     )
//     u_reorder_0(
//         .i_data_vld      ( select_toIQ0      ),
//         .i_datas         ( i_disp_info       ),
//         .o_data_vld      ( IQ0_has_selected  ),
//         .o_reorder_datas ( IQ0_selected_info )
//     );

//     reorder
//     #(
//         .dtype ( logic[`WDEF(`NUMSRCS_INT)] ),
//         .NUM   ( 4   )
//     )
//     u_reorder_1(
//         .i_data_vld      ( select_toIQ0   ),
//         .i_datas         ( i_enq_iprs_rdy ),
//         .o_reorder_datas ( IQ0_enq_iprs_rdy   )
//     );

//     reorder
//     #(
//         .dtype ( logic ),
//         .NUM   ( 4   )
//     )
//     u_reorder_2(
//         .i_data_vld      ( select_toIQ0   ),
//         .i_datas         ( i_enq_memdep_rdy ),
//         .o_reorder_datas ( IQ0_enq_memdep_rdy   )
//     );

//     generate
//         for (i=0; i < 2; i=i+1) begin
//             assign toLD_exeInfo[i] = '{
//                 ftq_idx     : IQ0_selected_info[i].ftq_idx,
//                 rob_idx     : IQ0_selected_info[i].rob_idx,
//                 irob_idx    : IQ0_selected_info[i].irob_idx,
//                 rd_wen      : IQ0_selected_info[i].rd_wen,
//                 iprd_idx    : IQ0_selected_info[i].iprd_idx,
//                 iprs_idx    : IQ0_selected_info[i].iprs_idx[0], // load only use rs1
//                 use_imm     : IQ0_selected_info[i].use_imm,
//                 issueQue_id : IQ0_selected_info[i].issueQue_id,
//                 micOp_type  : IQ0_selected_info[i].micOp_type,
//                 shouldwait  : IQ0_selected_info[i].shouldwait,
//                 dep_robIdx  : IQ0_selected_info[i].dep_robIdx,
//                 instmeta    : IQ0_selected_info[i].instmeta
//             };
//         end
//     endgenerate

//     wire[`WDEF(2)] IQ0_inst_vld;
//     wire[`WDEF($clog2(`IQ0_SIZE))] IQ0_inst_iqIdx[2];
//     microOp_t IQ0_inst_info[2];

//     wire[`WDEF(2)] IQ0_issue_finished;
//     wire[`WDEF(2)] IQ0_issue_failed;
//     wire[`WDEF($clog2(16))] IQ0_issue_iqIdx[2];

//     // IQ0 external wakeup from IQ1(2xalu+2xbru)
//     wire[`WDEF(2)] IQ0_ext_wake_vld = IQ1_export_wake_vld;
//     iprIdx_t IQ0_ext_wake_rdIdx[2];
//     assign IQ0_ext_wake_rdIdx = IQ1_export_wake_rdIdx;

//     issueQue_mem
//     #(
//         .DEPTH              ( `IQ0_SIZE     ),
//         .INOUTPORT_NUM      ( 2     ),
//         .EXTERNAL_WAKEUPNUM ( `WBPORT_NUM   ),
//         .WBPORT_NUM         ( `WBPORT_NUM   ),
//         .SINGLEEXE          ( 0     ),
//         .HASDEST            ( 1     ),
//     )
//     u_issueQue_load(
//         .clk                   ( clk ),
//         .rst                   ( rst || i_squash_vld ),

//         .o_can_enq             ( IQ0_ready ),
//         .i_enq_req             ( IQ0_has_selected[1:0] ),
//         .i_enq_exeInfo         ( toLD_exeInfo ),
//         .i_enq_iprs_rdy        ( {IQ0_enq_iprs_rdy[0], IQ0_enq_iprs_rdy[1]} ),
//         .i_enq_memdep_rdy      ( {IQ0_enq_memdep_rdy[0], IQ0_enq_memdep_rdy[1]} ),

//         .o_can_issue           ( IQ0_inst_vld   ),
//         .o_issue_idx           ( IQ0_inst_iqIdx ),
//         .o_issue_exeInfo       ( IQ0_inst_info  ),

//         .i_issue_finished_vec  ( IQ0_issue_finished ),
//         .i_issue_replay_vec    ( IQ0_issue_failed   ),
//         .i_feedback_idx        ( IQ0_issue_iqIdx    ),

//         .o_export_wakeup_vld   ( IQ0_export_wake_vld   ),
//         .o_export_wakeup_rdIdx ( IQ0_export_wake_rdIdx   ),

//         .i_ext_wakeup_vld      ( i_glob_wk_vec  ),
//         .i_ext_wakeup_rdIdx    ( i_glob_wk_iprd   ),

//         .i_wb_vld              ( i_glob_wb_vec   ),
//         .i_wb_rdIdx            ( i_glob_wb_iprd   )
//     );

//     assign o_iprs_idx[0] = IQ0_inst_info[0].iprs_idx;
//     assign o_iprs_idx[1] = IQ0_inst_info[1].iprs_idx;

//     assign o_immB_idx[0] = IQ0_inst_info[0].irob_idx;
//     assign o_immB_idx[1] = IQ0_inst_info[1].irob_idx;

//     reg[`WDEF(2)] s1_IQ0_inst_vld;
//     reg[`WDEF($clog2(`IQ0_SIZE))] s1_IQ0_inst_iqIdx[2];

//     iprIdx_t s1_IQ0_iprs_idx[2];
//     microOp_t s1_IQ0_inst_info[2];
//     always_ff @( posedge clk ) begin
//         int fa;
//         if (rst || i_squash_vld) begin
//             s1_IQ0_inst_vld <= 0;
//         end
//         else begin
//             // s0: read regfile
//             // s1: bypass
//             s1_IQ0_inst_vld <= IQ0_inst_vld;
//             s1_IQ0_iprs_idx[0] <= IQ0_inst_info[0].iprs_idx;
//             s1_IQ0_iprs_idx[1] <= IQ0_inst_info[1].iprs_idx;
//             s1_IQ0_inst_iqIdx <= IQ0_inst_iqIdx;
//             s1_IQ0_inst_info <= IQ0_inst_info;
//         end
//     end

// /****************************************************************************************************/
// // ldu
// /****************************************************************************************************/
// generate
// for(i=0; i<2; i=i+1) begin: gen_memBlk_loadfu
//     localparam int IQ0_fuID = i;
//     localparam int memBlock_fuID = i + 0;
//     localparam int global_fuID = i + 4;

//     wire fu_stall;
//     wire ldu_bypass_vld;
//     wire[`XDEF] ldu_bypass_data;

//     assign IQ0_issue_finished[IQ0_fuID] = 0;
//     assign IQ0_issue_failed[IQ0_fuID] = s1_IQ0_inst_vld[IQ0_fuID] && ((i_iprs_ready[memBlock_fuID] | ldu_bypass_vld) == 1'0);
//     assign IQ0_issue_iqIdx[IQ0_fuID] = s1_IQ0_inst_iqIdx[IQ0_fuID];

//     bypass_sel
//     #(
//         .WIDTH ( `BYPASS_WIDTH )
//     )
//     u_bypass_sel_0_src0(
//         .rst           ( rst ),
//         .i_src_vld     ( i_glob_bp_vec   ),
//         .i_src_idx     ( i_glob_bp_iprd ),
//         .i_src_data    ( i_glob_bp_data  ),
//         .i_target_idx  ( s1_IQ0_inst_info[IQ0_fuID].iprs_idx  ),
//         .o_target_vld  ( ldu_bypass_vld  ),
//         .o_target_data ( ldu_bypass_data )
//     );

//     exeInfo_t lsfu_info;
//     assign lsfu_info = '{
//         ftq_idx     : s1_IQ0_inst_info[IQ0_fuID].ftq_idx,
//         rob_idx     : s1_IQ0_inst_info[IQ0_fuID].rob_idx,
//         irob_idx    : s1_IQ0_inst_info[IQ0_fuID].irob_idx,
//         lq_idx      : 0,
//         sq_idx      : 0,
//         use_imm     : s1_IQ0_inst_info[IQ0_fuID].use_imm,
//         rd_wen      : s1_IQ0_inst_info[IQ0_fuID].rd_wen,
//         iprd_idx    : s1_IQ0_inst_info[IQ0_fuID].iprd_idx,
//         srcs        : {
//                 ldu_bypass_data ? ldu_bypass_data : i_iprs_data[memBlock_fuID], // rs1
//                 {{44{s1_irob_imm[intBlock_fuID][19]}},s1_irob_imm[intBlock_fuID]}  // imm
//             },
//         issueQue_id : s1_IQ0_inst_info[IQ0_fuID].issueQue_id,
//         micOp       : s1_IQ0_inst_info[IQ0_fuID].micOp,
//         instmeta    : s1_IQ0_inst_info[IQ0_fuID].instmeta
//     };

//     loadfu u_loadfu(
//         .clk            ( clk ),
//         .rst            ( rst || i_squash_vld ),

//         .o_stall        ( ),
//         .i_vld          ( s1_IQ0_inst_vld[IQ0_fuID] ),
//         .i_fuInfo       ( lsfu_info ),

//         .if_load2que    ( if_load2que   ),
//         .if_stfwd       (   ),
//         .if_load2cache  (   ),

//         .i_wb_stall     ( 0  ),
//         .o_fu_finished  ( fu_finished[memBlock_fuID] ),
//         .o_comwbInfo    ( comwbInfo[memBlock_fuID]   ),

//         .o_has_except   (  ),
//         .o_exceptwbInfo (  )
//     );


// end
// endgenerate



// /****************************************************************************************************/
// // stu
// /****************************************************************************************************/

// assign fu_finished[3:2] = 0;


// /****************************************************************************************************/
// // load queue
// /****************************************************************************************************/






// /****************************************************************************************************/
// // other
// /****************************************************************************************************/

//     assign o_exp_bp_vec = 0;

//     generate
//         for(i=0;i<`MEM_WBPORT_NUM;i=i+1) begin
//             assign o_exp_wk_vec[i] = 0;
//         end
//     endgenerate

endmodule
