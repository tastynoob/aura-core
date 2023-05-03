`include "decode_define.svh"


// we may need to implement lui-load imm bypassing
// lui x1,123; ld x2,1(x1) =>  ld x2,(123<<12)+1
module decode (
    input wire clk,
    input wire rst,

    input wire[`WDEF(`DECODE_WIDTH)] i_inst_vld,
    input wire[`IDEF] i_inst[`DECODE_WIDTH],
    input wire[`XDEF] i_predTakenPC,


    output reg[`WDEF(`DECODE_WIDTH)] o_decinfo_vld,
    output decInfo_t o_decinfo[`DECODE_WIDTH],
    output reg[`XDEF] o_predTakenPC
);
    genvar i;

    decInfo_t decinfo[`DECODE_WIDTH];
    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode
            decoder u_decoder(
                .i_inst           (i_inst[i]           ),
                .o_decinfo        (decinfo[i]        )
            );

        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            o_decinfo_vld <= 0;
        end
        else begin
            o_decinfo_vld <= i_inst_vld;
            o_decinfo <= decinfo;
            o_predTakenPC <= i_predTakenPC;
        end
    end



endmodule

