


// vld = a.len<=b.len
module bits_compare #(
    parameter int LENGTH = 32
) (
    input wire[`WDEF(LENGTH)] i_a,
    input wire[`WDEF(LENGTH)] i_b,
    output wire o_vld
);

    wire[`SDEF(LENGTH)] alen, blen;

    count_one
    #(
        .WIDTH ( LENGTH )
    )
    u_count_one_0(
        .i_a   ( i_a   ),
        .o_sum ( alen )
    );

    count_one
    #(
        .WIDTH ( LENGTH )
    )
    u_count_one_1(
        .i_a   ( i_b   ),
        .o_sum ( blen )
    );

    assign o_vld = alen <= blen;

endmodule

