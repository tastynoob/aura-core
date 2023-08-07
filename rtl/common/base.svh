`ifndef __BASE_SVH__
`define __BASE_SVH__

typedef enum logic {
    true  = 1'b1,
    false = 1'b0
} bool_e;


//bit width fast define
`define WDEF(x) ((``x``) == 0 ? 0 : ((``x``)-1)):0
//bit size fast define, actually it will allocate 1 more bit
`define SDEF(x) $clog2(``x``):0

`define ASSERT(x) always_ff @(posedge clk) assert((``x``) || rst)
// `define ORDER_CHECK(x) `ASSERT(continuous_one(``x``) == count_one(``x``))
`define ORDER_CHECK(x)

`define SET_TRACE_OFF /*verilator tracing_off*/
`define SET_TRACE_ON /*verilator tracing_on*/

`endif
