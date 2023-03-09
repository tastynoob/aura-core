`include "rtl/common/package.sv"
import pkg_baseType::*;

module fifo #(
    parameter type dtype = logic,
    parameter DEPTH = 32
) (
    input wire i_clk
);
endmodule
