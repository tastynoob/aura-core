`include "core_define.svh"


// DESIGN:
// (1) if we found one inst is unknow:
// send message for commit, stop fetch, wait for squash signal
// (2) if we found one inst need serialize:
// first: output insts that before serialized inst
// stall decode, wait for rob to be empty
// commit send to decode the signal and output the serialized inst
// wait for serialized inst is retired
// start normal execute

//TODO: finish above


// TODO:
// we may need to implement lui-load imm bypassing
// lui x1,123; ld x2,1(x1) =>  ld x2,(123<<12)+1
module decode (
    input wire clk,
    input wire rst,
    // squash
    input wire i_squash_vld,
    // to fetch
    output wire o_stall,
    // from rename
    input wire i_stall,

    input wire[`WDEF(`DECODE_WIDTH)] i_inst_vld,
    input wire[`IDEF] i_inst[`DECODE_WIDTH],
    input wire[`XDEF] i_inst_npc,

    output reg[`WDEF(`DECODE_WIDTH)] o_decinfo_vld,
    output decInfo_t o_decinfo[`DECODE_WIDTH]
);
    genvar i;

    wire[`WDEF(`DECODE_WIDTH)] unknow_inst;
    decInfo_t decinfo[`DECODE_WIDTH];
    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode
            decoder u_decoder(
                .i_inst           ( i_inst[i]     ),
                .i_inst_npc       ( i_inst_npc[i] ),
                .o_unknow_inst    ( unknow_inst   ),
                .o_decinfo        ( decinfo[i]    )
            );

        end
    endgenerate

    always_ff @(posedge clk) begin
        if ((rst==true) || i_squash_vld) begin
            o_decinfo_vld <= 0;
        end
        else if (!i_stall) begin
            o_decinfo_vld <= i_inst_vld;
            o_decinfo <= decinfo;
        end
    end


endmodule

