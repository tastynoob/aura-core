`include "core_define.svh"





module exeBlock(
    input wire clk,
    input wire rst,

    // from dispatch
    input wire[`WDEF(`RENAME_WIDTH)] i_disp_mark_notready_vld,
    input iprIdx_t i_disp_mark_notready_iprIdx[`RENAME_WIDTH],

    output wire o_intBlock_stall,
    input wire[`WDEF(`INTDQ_DISP_WID)] i_intDQ_deq_vld,
    input intDQEntry_t i_intDQ_deq_info[`INTDQ_DISP_WID],

    // writeback to rob
    // common writeback
    output wire[`WDEF(`WBPORT_NUM)] o_wb_vld,
    output valwbInfo_t o_wbInfo[`WBPORT_NUM],
    // branch writeback (branch taken or mispred)
    output wire o_branchwb_vld,
    output branchwbInfo_t o_branchwb_info,
    // except writeback
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info
);



    regfile
    #(
        .READPORT_NUM ( 8 ),
        .WBPORT_NUM   ( 8   ),
        .SIZE         ( `IPHYREG_NUM         ),
        .HAS_ZERO     ( 1     )
    )
    u_regfile(
        .clk                  ( clk                  ),
        .rst                  ( rst                  ),
        // rename to disp
        .i_notready_mark      ( i_disp_mark_notready_vld    ),
        .i_notready_iprIdx    ( i_disp_mark_notready_iprIdx ),
        // disp to issueQue
        .i_dsip_check_iprsIdx  (   ),
        .o_disp_check_iprs_vld (  ),

        .i_read_idx           (            ),
        .o_data_rdy           (            ),
        .o_read_data          (           ),
        .i_write_en           (            ),
        .i_write_idx          (           ),
        .i_write_data         (          )
    );





    intBlock
    #(
        .INPUT_NUM       ( `INTDQ_DISP_WID       ),
        .EXTERNAL_WAKEUP ( 0 ),
        .FU_NUM          ( 6          )
    )
    u_intBlock(
        .clk                 ( clk                 ),
        .rst                 ( rst                 ),

        .i_squash_vld        (         ),
        .i_squashInfo        (         ),

        .i_disp_vld          (           ),
        .o_can_disp          (           ),
        .i_disp_info         (          ),

        .o_iprs_idx          (           ),
        .i_iprs_ready        (         ),
        .i_iprs_data         (          ),

        .o_immB_idx          (           ),
        .i_imm_data          (           ),

        .o_read_ftqIdx       (        ),
        .i_read_ftqStartAddr (  ),
        .i_read_ftqNextAddr  (   ),

        .i_wb_stall          (           ),
        .o_wb_vld            (             ),
        .o_valwb_info        (         ),
        .o_branchWB_vld      (       ),
        .o_branchWB_info     (      ),
        .i_exceptwb_vld      (       ),
        .i_exceptwb_info     (      ),

        .i_ext_wake_vec      (       ),
        .i_ext_wake_prdIdx   (    ),
        .i_ext_wake_data     (      )
    );









endmodule
