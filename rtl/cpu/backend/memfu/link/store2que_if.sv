`include "backend_define.svh"







interface store2que_if;
    // stau
    logic vld;
    sqIdx_t sqIdx;
    robIdx_t robIdx;
    logic [`XDEF] vaddr;
    paddr_t paddr;
    logic[`WDEF(`XLEN/8)] storemask;
    // only for stdu
    logic [`XDEF] data;

    modport m(
        output vld,
        output sqIdx,
        output robIdx,
        output vaddr,
        output paddr,
        output storemask,
        output data
    );
    modport s(
        input vld,
        input sqIdx,
        input robIdx,
        input vaddr,
        input paddr,
        input storemask,
        input data
    );

endinterface
