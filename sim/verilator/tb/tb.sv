
`include "core_define.svh"
`include "frontend_define.svh"

package tilelink_enum;
    const logic[`WDEF(3)] a = 1;
endpackage

module tb (
    input wire clk,
    input wire rst
);

    wire a = tilelink_enum::a;

endmodule



