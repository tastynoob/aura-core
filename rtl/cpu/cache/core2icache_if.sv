`include "core_define.svh"



// if fetch addr is not aligned by 4 bytes
// core will send 2 request for 2 cacheline

interface core2icache_if();
    logic req;//M->S
    logic get2;//M->S
    logic gnt;//S->M
    logic[`BLKDEF] addr;//M->S
    logic[`WDEF(`CACHELINE_SIZE*8)] line0;//S->M
    logic[`WDEF(`CACHELINE_SIZE*8)] line1;//S->M
    logic rsp;//S->M
    modport m (
        output req,
        input gnt,
        output get2,
        output addr,
        input line0,
        input line1,
        input rsp
    );
    modport s (
        input req,
        output gnt,
        input get2,
        input addr,
        output line0,
        output line1,
        output rsp
    );


    function logic handshaked();
        handshaked = req && gnt;
    endfunction

endinterface








