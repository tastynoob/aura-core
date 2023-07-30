`include "base.svh"





// s0: read plru select
// s1: cache hit and update plru

module plru_rep #(
    parameter int SETS = 32,
    parameter int WAYS = 4
) (
    input wrie clk,
    input wire rst,

    input wire[`WDEF($clog2(SETS))] i_setIdx,
    output wire[`WDEF(WAYS)] o_replace_vec,
    input wire i_update_req,
    input wire[`WDEF(WAYS)] i_wayhit_vec
);
    localparam int plru_wid = WAYS -1;

    reg[`WDEF(plru_wid)] plru_bits[SETS];



endmodule
