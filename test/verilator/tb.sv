
module tb (
    input clk,
    input rst
);

    wire [5:0] out;

    continuous_one #(
        .WIDTH(6)
    ) u_continuous_one (
        .i_a  (6'b111111),
        .o_sum(out)
    );


endmodule


