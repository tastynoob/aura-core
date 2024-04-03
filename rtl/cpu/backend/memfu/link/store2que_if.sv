`include "backend_define.svh"







interface store2que_if;
    // stau
    logic vld;
    sqIdx_t sqIdx;
    logic [`XDEF] vaddr;
    paddr_t paddr;
    logic [`XDEF] data;  // only for stdu

    modport m(output vld, output sqIdx, output vaddr, output paddr, output data);

endinterface
