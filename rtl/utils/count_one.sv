`include "base.svh"

//get the number of 1 of logic
//0101 => 2
module count_one #(
    parameter int WIDTH = 4
) (
    input wire [`WDEF(WIDTH)] i_a,
    output wire [`SDEF(WIDTH)] o_sum
);
    /* verilator lint_off UNOPTFLAT */
    wire [`SDEF(WIDTH)] buffer[WIDTH+1];
    assign buffer[0] = 0;
    generate
        genvar i;
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_count
            assign buffer[i+1] = i_a[i] ? buffer[i] + 1 : buffer[i];
        end
    endgenerate
    assign o_sum = buffer[WIDTH];
endmodule

