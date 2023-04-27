`include "rename_define.svh"
`include "decode_define.svh"

//
module rename(
    input wire rst,
    input wire clk,
    input wire[`WDEF(`DECODE_WIDTH)] i_decinfo_vld,
    input decInfo_t i_decinfo[`DECODE_WIDTH],
    //to int block
    output wire[`WDEF(`RENAME_WIDTH)] o_disp_intblock,
    //to mem block
    output wire[`WDEF(`RENAME_WIDTH)] o_disp_memblock,

    //to float block TODO: not implemented
    output wire[`WDEF(`RENAME_WIDTH)] o_disp_fltblock
);


endmodule

