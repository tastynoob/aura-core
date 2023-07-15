
`include "core_define.svh"

module tb #(
    parameter int WIDTH = 4
)(
    input wire clk,
    input wire rst
);


ctrlBlock u_ctrlBlock(
    .clk                   (clk                   ),
    .rst                   (rst                   )
);




endmodule



