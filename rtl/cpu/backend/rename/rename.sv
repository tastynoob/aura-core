`include "rename_define.svh"
`include "decode_define.svh"

//
module rename(
    input wire rst,
    input wire clk,
    input wire[`WDEF(`DECODE_WIDTH)] i_decinfo_vld,
    input decInfo_t i_decinfo[`DECODE_WIDTH],
    input wire[`XDEF] i_predTakenPC,

    output wire[`WDEF(`RENAME_WIDTH)] o_rename_vld,
    output renameInfo_t o_renameInfo[`RENAME_WIDTH]
);


endmodule

