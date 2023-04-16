`include "base.svh"

//get the continuous one of begin of logic
//0011 => 2
//0101 => 1

module continuous_one #(
    parameter int WIDTH = 4
) (
    input  wire [`WDEF(WIDTH)] i_a,
    output wire [`SDEF(WIDTH)] o_sum
);
    /* verilator lint_off UNOPTFLAT */
    wire [`SDEF(WIDTH)] map[WIDTH];
    assign map[0] = i_a[0];
    generate
        genvar i;
        for (i = 1; i < WIDTH; i = i + 1) begin: gen_count
            assign map[i] = &i_a[i:0] ? i+1 : map[i-1];
        end
    endgenerate
    assign o_sum = map[WIDTH-1];
endmodule

