`include "backend_define.svh"




interface staviocheck_if;
    logic vld;
    sqIdx_t sqIdx;
    logic[`XDEF] paddr;
    logic[`WDEF(`XLEN/8)] mask;

    logic vio;
    robIdx_t vioload_robIdx;

endinterface
