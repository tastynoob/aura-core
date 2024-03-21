`include "backend_define.svh"



// loadpipe to load/storeQue
interface load2que_if;
    logic vld;
    lqIdx_t lqIdx;
    logic [`XDEF] vaddr;
    paddr_t paddr;
    logic [`WDEF(`XLEN/8)] loadmask;  // 8 byte aligned


    modport m(output vld, output lqIdx, output vaddr, output paddr, output loadmask);

    modport s(input vld, input lqIdx, input vaddr, input paddr, input loadmask);
endinterface


