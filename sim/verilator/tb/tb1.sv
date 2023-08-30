
`include "core_define.svh"
`include "frontend_define.svh"

module tb1 (
    input wire clk,
    input wire rst
);



robIdx_t ages[6];
assign ages = {
    134,133,132,131,130,129
};

age_schedule
#(
    .WIDTH (6 ),
    .OUTS  (2  )
)
u_age_schedule(
    .clk       ( clk       ),
    .rst       ( rst       ),
    .i_vld     ( {1'b1,1'b1,1'b1,1'b1,1'b1,1'b0}     ),
    .i_ages    ( ages    ),
    .o_vld     (      ),
    .o_sel_idx ( )
);



endmodule



