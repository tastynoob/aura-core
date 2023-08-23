`include "base.svh"








module random_rep #(
    parameter int SETS = 32,
    parameter int WAYS = 4

) (
    input wire clk,
    input wire rst,

    input wire[`WDEF($clog2(SETS))] i_setIdx,
    output wire[`WDEF(WAYS)] o_replace_vec,
    input wire i_update_req,
    input wire[`WDEF(WAYS)] i_wayhit_vec
);
    reg[`WDEF(WAYS)] rand_bits;


    always_ff @( posedge clk ) begin
        if (rst) begin
            rand_bits <= 1;
        end
        else begin
            rand_bits <= {rand_bits[0], rand_bits[WAYS-1:1]};
        end
    end

    assign o_replace_vec = rand_bits;



endmodule

