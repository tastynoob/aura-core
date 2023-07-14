`include "core_define.svh"


// DESIGN:
// (1) if we found one inst is unknow:
// let inst take the except code
// check except at commit
// (2) if we found one inst need serialize:
// let inst take the serialize code
// at dispatch: wait for rob is empty
// stall pipeline, wait for rob commit signal

//TODO: finish above


// TODO:
// we may need to implement lui-load imm bypassing
// lui x1,123; ld x2,1(x1) =>  ld x2,(123<<12)+1
module decode (
    input wire clk,
    input wire rst,
    // to fetch
    output wire o_stall,
    // from rename
    input wire i_stall,
    // squash
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from fetchBuffer
    // which inst need to deq from fetchbuffer
    output wire[`WDEF(`DECODE_WIDTH)] o_can_deq,
    input wire[`WDEF(`DECODE_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`DECODE_WIDTH],
    // to rename
    output reg[`WDEF(`DECODE_WIDTH)] o_decinfo_vld,
    output decInfo_t o_decinfo[`DECODE_WIDTH]
);
    genvar i;
    integer a;
    `ORDER_CHECK(real_inst_vld);

    wire[`WDEF(`DECODE_WIDTH)] unKnown_inst;
    decInfo_t decinfo[`DECODE_WIDTH];
    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode
            decoder u_decoder(
                .i_inst           ( i_inst[i].inst      ),
                .o_unkown_inst    ( unKnown_inst[i]),
                .o_decinfo        ( decinfo[i]     )
            );

        end
    endgenerate

    always_comb begin
        for(a=0;a<`DECODE_WIDTH;a=a+1) begin
            decinfo[a].ftq_idx = i_inst[i].ftq_idx;
            decinfo[a].ftqOffset = i_inst[i].ftqOffset;
            decinfo[a].has_except = unKnown_inst || i_inst[i].has_except;
            decinfo[a].except = unKnown_inst ? rv_trap_t::instIllegal : i_inst[i].except;
        end
        o_can_deq = (i_stall) ? 0 : i_inst_vld;
        o_decinfo_vld = i_inst_vld;
    end

endmodule

