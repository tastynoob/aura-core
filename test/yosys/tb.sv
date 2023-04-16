
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
    input wire[`WDEF(32)] vld,
    output wire [`WDEF(WIDTH)] o_sum
);
    always_comb begin : blockName
        o_sum =0;
        for(integer i=0;i<32;i=i+1) begin
            if (vld[i]) begin
                o_sum = i;
            end
        end
    end
endmodule


