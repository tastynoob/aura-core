`include "backend_define.svh"



// loadpipe to load/storeQue
interface load2que_if;
    // load s2
    logic vld;
    lqIdx_t lqIdx;
    sqIdx_t sqIdx;
    logic [`XDEF] vaddr;
    paddr_t paddr;
    logic [`WDEF(`XLEN/8)] loadmask;  // 8 byte aligned

    robIdx_t robIdx;
    logic [`XDEF] pc;


    modport m(
        output vld,
        output lqIdx,
        output sqIdx,
        output vaddr,
        output paddr,
        output loadmask,
        output robIdx,
        output pc
    );

    modport s(
        input vld,
        input lqIdx,
        input sqIdx,
        input vaddr,
        input paddr,
        input loadmask,
        input robIdx,
        input pc
    );
endinterface


