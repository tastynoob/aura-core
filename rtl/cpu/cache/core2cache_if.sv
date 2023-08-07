`include "core_define.svh"



// if fetch addr is not aligned by 4 bytes
// core will send 2 request for 2 cacheline

interface core2icache_if();
    logic req;//M->S
    logic gnt;//S->M
    logic[`XDEF] addr;//M->S
    logic[`WDEF(`CACHELINE_SIZE)] rdata;//S->M
    logic rsp;//S->M
    modport m (
        output req,
        input gnt,
        output addr,
        input rdata,
        input rsp
    );
    modport s (
        input req,
        output gnt,
        input addr,
        output rdata,
        output rsp
    );
endinterface








