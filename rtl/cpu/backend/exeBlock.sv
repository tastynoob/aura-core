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
    output commWBInfo_t o_wbInfo[`WBPORT_NUM],
    // branch writeback (branch taken or mispred)
    output wire o_branchwb_vld,
    output branchWBInfo_t o_branchwb_info,
    // except writeback
    output wire o_exceptwb_vld,
    output exceptWBInfo_t o_exceptwb_info
);


endmodule
