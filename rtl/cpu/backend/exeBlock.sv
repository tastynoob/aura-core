`include "core_define.svh"





module exeBlock(
    input wire clk,
    input wire rst,

    // from dispatch
    input wire[`WDEF(`RENAME_WIDTH)] i_disp_mark_notready_vld,
    input iprIdx_t i_disp_mark_notready_iprIdx[`RENAME_WIDTH],

    output wire[`WDEF(`INTDQ_DISP_WID)] o_intDQ_deq_vld,
    input wire[`WDEF(`INTDQ_DISP_WID)] i_intDQ_deq_req,
    input intDQEntry_t i_intDQ_deq_info[`INTDQ_DISP_WID],

    output irobIdx_t o_read_irob_idx[`ALU_NUM],
    input wire[`IMMDEF] i_read_irob_data[`ALU_NUM],
    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    input wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],
    input wire[`XDEF] i_read_ftqNextAddr[`BRU_NUM],

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
        .READPORT_NUM ( 12 ),
        .WBPORT_NUM   ( 8   ),
        .SIZE         ( `IPHYREG_NUM         ),
        .HAS_ZERO     ( 1     )
    )
    u_regfile(
        .clk                   ( clk                  ),
        .rst                   ( rst                  ),
        // rename to disp
        .i_notready_mark       ( i_disp_mark_notready_vld    ),
        .i_notready_iprIdx     ( i_disp_mark_notready_iprIdx ),
        // disp to issueQue
        .i_dsip_check_iprsIdx  (   ),
        .o_disp_check_iprs_vld (  ),

        .i_read_idx   (          ),
        .o_data_rdy   (          ),
        .o_read_data  (          ),
        .i_write_en   (          ),
        .i_write_idx  (          ),
        .i_write_data (          )
    );


    iprIdx_t intBlock_iprs_idx[6][`NUMSRCS_INT];
    wire[`WDEF(6)] toIntBlock_iprs_rdy[`NUMSRCS_INT];
    wire[`XDEF] toIntBlock_iprs_data[6][`NUMSRCS_INT];

    wire[`WDEF(6)] intBlock_valwb_vld;
    valwbInfo_t intBlock_valwb[6];
    wire[`WDEF(`BRU_NUM)] intBlock_branchwb_vld;
    branchwbInfo_t intBlock_branchwb[`BRU_NUM];
    wire intBlock_exceptwb_vld;
    exceptwbInfo_t intBlock_exceptwb;
    intBlock
    #(
        .INPUT_NUM          ( `INTDQ_DISP_WID       ),
        .EXTERNAL_WRITEBACK ( 0 ),
        .EXTERNAL_WAKEUP    ( 0 ),
        .FU_NUM             ( 6 )
    )
    u_intBlock(
        .clk                 ( clk     ),
        .rst                 ( rst     ),

        .i_squash_vld        ( 0       ),
        .i_squashInfo        (         ),

        .o_disp_vld          ( o_intDQ_deq_vld      ),
        .i_dsip_req          ( i_intDQ_deq_req      ),
        .i_disp_info         ( i_intDQ_deq_info     ),

        .o_iprs_idx          ( intBlock_iprs_idx    ),
        .i_iprs_ready        ( toIntBlock_iprs_rdy  ),
        .i_iprs_data         ( toIntBlock_iprs_data ),

        .o_immB_idx          ( o_read_irob_idx  ),
        .i_imm_data          ( i_read_irob_data ),

        .o_read_ftqIdx       ( o_read_ftqIdx       ),
        .i_read_ftqStartAddr ( i_read_ftqStartAddr ),
        .i_read_ftqNextAddr  ( i_read_ftqNextAddr  ),

        .i_wb_stall        ( 0     ),
        .o_wb_vld          ( intBlock_valwb_vld ),
        .o_valwb_info      ( intBlock_valwb     ),

        .o_branchWB_vld    ( intBlock_branchwb_vld ),
        .o_branchWB_info   ( intBlock_branchwb     ),
        .i_exceptwb_vld    ( intBlock_exceptwb_vld ),
        .i_exceptwb_info   ( intBlock_exceptwb     ),

        .i_ext_wake_vec    ( 0     ),
        .i_ext_wake_rdIdx  (      ),

        .i_ext_wb_vec      ( 0     ),
        .i_ext_wb_rdIdx    (      ),
        .i_ext_wb_data     (      )
    );









endmodule
