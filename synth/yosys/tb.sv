
`define WDEF(x) (``x``)-1:0

module tb (
    input clk,
    input rst,
    input[`WDEF(4)] a,
    input[`WDEF(4)] b,
    output[`WDEF(6)] o
);


assign o = a+b < 20;




endmodule




