
`include "core_define.svh"

module tb #(
    parameter int WIDTH = 4
)(
    input wire clk,
    input wire rst
);



oldest_select
#(
    .WIDTH (3 )
)
u_oldest_select(
    .i_rob_idx        (        ),
    .o_oldest_rob_idx ( )
);



endmodule



