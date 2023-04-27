`include "decode_define.svh"


// we may need to implement lui-load imm bypassing
// lui x1,123; ld x2,1(x1) =>  ld x2,(123<<12)+1
module decode (
    input wire clk,
    input wire rst,

    input wire[`WDEF(`DECODE_WIDTH)] i_inst_vld,
    input decInfo_t i_inst[`DECODE_WIDTH],

    output wire[`WDEF(`DECODE_WIDTH)] o_decinfo_vld,
    output decInfo_t o_decinfo[`DECODE_WIDTH]
);
    genvar i;

    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode

        end
    endgenerate





endmodule

