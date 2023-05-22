

typedef struct {
    logic[31:0] a;
    logic[31:0] b;
} PPP_t;


module tb (
    input clk,
    input rst
);

    wire[31:0] a,b;
    test u_test(
        .i_a ( {32'd1,32'd2} ),
        .o_b ( {a,b} )
    );


endmodule




module test(
    input PPP_t i_a,
    output PPP_t o_b
);
    assign o_b = '{i_a.b,i_a.a};
endmodule

