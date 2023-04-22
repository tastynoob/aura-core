
typedef enum logic {
    true  = 1'b1,
    false = 1'b0
} bool_e;


//bit width fast define
`define WDEF(x) (``x``)-1:0
//bit size fast define, actually it will allocate 1 more bit
`define SDEF(x) $clog2(``x``):0


module tb #(
    parameter int WIDTH = 4
) (
    input clk,
    input a,
    output b
);
    reg t0,t1;
    always_ff @(posedge clk) begin
        t0<=a;
        t1<=t0;
    end
    assign b=t1;
endmodule


