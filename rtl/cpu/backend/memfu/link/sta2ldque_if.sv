`include "backend_define.svh"



// staFu to loadQue
// store-load violation check
interface sta2ldque_if;

    logic s0_vld;
    sqIdx_t s0_sqIdx;
    logic[`XDEF] s0_sta_vaddr;
    logic[`WDEF(`XLEN/8)] s0_store_vec;

    modport m (
        output s0_vld,
        output s0_sqIdx,
        output s0_sta_vaddr,
        output s0_store_vec
    );

    modport s (
        input s0_vld,
        input s0_sqIdx,
        input s0_sta_vaddr,
        input s0_store_vec
    );
endinterface
