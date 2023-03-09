`ifndef __PACKAGE_HH__
`define __PACKAGE_HH__


package pkg_baseType;
    typedef enum logic {
        false = 1'b0,
        true  = 1'b1
    } bool;

endpackage

import pkg_baseType::*;


typedef struct packed {
    logic clk;
    logic rst;
} sys_ctrl;

interface fifo_wport #(
    parameter type dtype = logic
);
    dtype data;
    bool  push;
    bool  data_vld;
    modport M(input data, input push, output data_vld);
    modport S(output data, output push, input data_vld);
endinterface

interface fifo_rport #(
    parameter type dtype = logic
);
    dtype data;
    bool  pop;
    bool  data_vld;
    modport M(output data, input pop, output data_vld);
    modport S(input data, output pop, input data_vld);
endinterface

`endif
