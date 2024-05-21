`include "backend_define.svh"


interface store2dcache_if;
    // s0:
    logic req;
    logic gnt;
    paddr_t paddr;
    logic [`XDEF] storedata;
    logic [`WDEF(`XLEN/8)] storemask;
    // s2:
    logic s2_finish;

    modport m(
        output req,
        input gnt,
        output paddr,
        output storedata,
        output storemask,

        input s2_finish
    );

    modport s(
        input req,
        output gnt,
        input paddr,
        input storedata,
        input storemask,

        output s2_finish
    );
endinterface

