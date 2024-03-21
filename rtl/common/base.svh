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

`define MASK(s, e) (((1<<(``s``)) - 1) & (~((1<<(``e``)) - 1)))

`define ASSERT(x) always_ff @(posedge clk) if (!rst) assert((``x``))
`define ORDER_CHECK(x) `ASSERT(funcs::continuous_one(``x``) == funcs::count_one(``x``))

`define PICK_ARRAY_MEMBER(pick_vec, array, member, size) \
generate                                        \
    for(genvar tmp_expand=0;tmp_expand<``size``;tmp_expand=tmp_expand+1) begin \
        assign ``pick_vec``[tmp_expand] = ``array``[tmp_expand].``member``; \
    end \
endgenerate

`define ARRAY_TO_VECTOR(vector, array) \
    for (genvar tmp_expand=0; tmp_expand<`SIZE; tmp_expand=tmp_expand+1) begin \
        assign vector[tmp_expand] = array[tmp_expand]; \
    end

`define DEBUG_EXP(x) ``x``
`undef DEBUG_EXP

`define SET_TRACE_OFF /*verilator tracing_off*/
`define SET_TRACE_ON /*verilator tracing_on*/

typedef longint unsigned uint64_t;

`include "difftest_def.svh"

`endif
