`include "backend_define.svh"







interface store2que_if;
    // stau
    logic vld;
    lqIdx_t lqIdx;
    sqIdx_t sqIdx;
    logic[`XDEF] vaddr;
    paddr_t paddr;

    // stdu
    logic vld;
    sqIdx_t sqIdx;
    logic[`XDEF] data;


endinterface
