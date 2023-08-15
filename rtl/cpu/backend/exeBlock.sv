`include "core_define.svh"





module exeBlock(
    input wire clk,
    input wire rst,

    // from dispatch
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






    intBlock
    #(
        .INPUT_NUM       ( 4       ),
        .EXTERNAL_WAKEUP ( 2 ),
        .FU_NUM          ( 6          )
    )
    u_intBlock(
        .clk                 ( clk                 ),
        .rst                 ( rst                 ),
        .i_squash_vld        ( i_squash_vld        ),
        .i_squashInfo        ( i_squashInfo        ),
        .i_disp_vld          ( i_disp_vld          ),
        .o_can_disp          ( o_can_disp          ),
        .i_disp_info         ( i_disp_info         ),
        .o_iprs_idx          ( o_iprs_idx          ),
        .i_iprs_ready        ( i_iprs_ready        ),
        .i_iprs_data         ( i_iprs_data         ),
        .o_immB_idx          ( o_immB_idx          ),
        .i_imm_data          ( i_imm_data          ),
        .o_read_ftqIdx       ( o_read_ftqIdx       ),
        .i_read_ftqStartAddr ( i_read_ftqStartAddr ),
        .o_read_ftqIdx       ( o_read_ftqIdx       ),
        .i_read_ftqStartAddr ( i_read_ftqStartAddr ),
        .i_wb_stall          ( i_wb_stall          ),
        .o_wb_vld            ( o_wb_vld            ),
        .o_valwb_info        ( o_valwb_info        ),
        .o_branchWB_vld      ( o_branchWB_vld      ),
        .o_branchWB_info     ( o_branchWB_info     ),
        .i_exceptwb_vld      ( i_exceptwb_vld      ),
        .i_exceptwb_info     ( i_exceptwb_info     ),
        .i_ext_wake_vec      ( i_ext_wake_vec      ),
        .i_ext_wake_prdIdx   ( i_ext_wake_prdIdx   ),
        .i_ext_wake_data     ( i_ext_wake_data     )
    );









endmodule
