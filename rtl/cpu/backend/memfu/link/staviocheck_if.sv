`include "backend_define.svh"




interface staviocheck_if;
    // s1
    logic vld;
    sqIdx_t sqIdx;
    paddr_t paddr;
    logic [`WDEF(`XLEN/8)] mask;
    // s2
    logic vio;
    robIdx_t vioload_robIdx;
    logic [`XDEF] vioload_pc;

    modport m (
        output vld,
        output sqIdx,
        output paddr,
        output mask,

        input vio,
        input vioload_robIdx,
        input vioload_pc
    );

    modport s (
        input vld,
        input sqIdx,
        input paddr,
        input mask,

        output vio,
        output vioload_robIdx,
        output vioload_pc
    );

endinterface
