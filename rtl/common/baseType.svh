`ifndef __PACKAGE_HH__
`define __PACKAGE_HH__

typedef enum logic {
    true  = 1'b1,
    false = 1'b0
} bool_e;

`define ASSERT(x) always_comb assert(``x``)
//bit width fast define
`define WDEF(x) (``x``)-1:0
//bit size fast define
`define SDEF(x) $clog2(``x``):0


`endif
