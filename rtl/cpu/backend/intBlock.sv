
`include "core_define.svh"



// DESIGN:
// issue -> read regfile/immBuffer/branchBuffer/ftq -> bypass/calcuate pc -> execute
// pc = (ftq_base_pc << offsetLen) + offset


// wakeup link
// alu -> alu
// alu -> lsu
// alu -> mdu
// mdu -> alu


module intBlock #(
    parameter int INPUT_NUM = `DISP_TO_INT_BLOCK_PORTNUM,
    parameter int EXTERNAL_WAKEUP = 2,// external wake up sources
    parameter int FU_NUM = 6
)(
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    // from dispatch
    input wire[`WDEF(INPUT_NUM)] i_disp_vld,
    input intDQEntry_t i_disp_info[INPUT_NUM],
    // regfile read
    output iprIdx_t o_iprs_idx[(ALU_NUM + MDU_NUM + BRU_NUM) * 2][`NUMSRCS_INT],// read regfile
    input wire[`WDEF((ALU_NUM + MDU_NUM + BRU_NUM) * 2)] o_iprs_ready[`NUMSRCS_INT],// ready or not
    input wire[`XDEF] i_iprs_data[(ALU_NUM + MDU_NUM + BRU_NUM) * 2][`NUMSRCS_INT],
    // immBuffer read
    output irobIdx_t o_immB_idx[ALU_NUM + BRU_NUM],
    input wire[`IMMDEF] i_imm_data[ALU_NUM + BRU_NUM],

    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_ftq_idx[`BRU_NUM],
    output wire[`XDEF] i_ftq_startAddress[`BRU_NUM],

    // read ftqOffset (to ROB)
    output ftqIdx_t o_ftq_idx[`BRU_NUM],
    output wire[`XDEF] i_ftq_startAddress[`BRU_NUM],

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
    input iprIdx_t i_ext_wake_prdIdx[EXTERNAL_WAKEUP]

);

    valwbInfo_t wbInfo[FU_NUM];
    wire[`WDEF(2)] IQ0_can_enq,IQ1_can_enq;
    logic[`WDEF(2)] IQ0_selected,IQ1_selected;
    logic[`WDEF($clog2(4))] IQ0_select_ptr[2], IQ1_select_ptr[2];


    always_comb begin
        int ca,cb;
        for(ca=0;ca < 4;ca=ca+1) begin
            if (ca % 2==0) begin

            end
            else begin

            end
        end
    end


    assign o_valwb_info = wbInfo;

/****************************************************************************************************/
// IQ0: 1x(alu+scu) + 1x(alu)
/****************************************************************************************************/

    wire IQ0_stall;


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
        .i_stall               ( i_stall               ),

        .o_can_enq             ( IQ0_can_enq           ),
        .i_enq_req             ( i_enq_req             ),
        .i_enq_exeInfo         ( i_enq_exeInfo         ),

        .o_can_issue           ( o_can_issue           ),
        .o_issue_idx           ( o_issue_idx           ),
        .o_issue_exeInfo       ( o_issue_exeInfo       ),

        .i_issue_finished_vec  ( i_issue_finished_vec  ),
        .i_issue_replay_vec    ( i_issue_replay_vec    ),
        .i_feedback_idx        ( i_feedback_idx        ),

        .o_export_wakeup_vld   ( o_export_wakeup_vld   ),
        .o_export_wakeup_rdIdx ( o_export_wakeup_rdIdx ),

        .i_ext_wakeup_vld      ( i_ext_wakeup_vld      ),
        .i_ext_wakeup_rdIdx    ( i_ext_wakeup_rdIdx    ),

        .i_wb_vld              ( i_wb_vld              ),
        .i_wb_rdIdx            ( i_wb_rdIdx            )
    );



    //fu0
    alu u_alu(
        .clk               ( clk               ),
        .rst               ( rst               ),

        .o_fu_stall        ( o_fu_stall        ),
        .i_fuInfo          ( i_fuInfo          ),

        .o_willwrite_vld   ( ),
        .o_willwrite_rdIdx ( o_willwrite_rdIdx ),
        .o_willwrite_data  ( o_willwrite_data  ),

        .i_wb_stall        ( i_wb_stall[0]     ),
        .o_wbInfo          ( wbInfo[0]         )
    );

    //fu1
    alu u_alu(
        .clk               ( clk               ),
        .rst               ( rst               ),

        .o_fu_stall        ( o_fu_stall        ),
        .i_fuInfo          ( i_fuInfo          ),

        .o_willwrite_vld   ( ),
        .o_willwrite_rdIdx ( o_willwrite_rdIdx ),
        .o_willwrite_data  ( o_willwrite_data  ),

        .i_wb_stall        ( i_wb_stall[1]        ),
        .o_wbInfo          ( wbInfo[1]          )
    );



/****************************************************************************************************/
// IQ1: 2x(alu+bru)
/****************************************************************************************************/




/****************************************************************************************************/
// IQ2: 2x(mdu)
/****************************************************************************************************/





endmodule


