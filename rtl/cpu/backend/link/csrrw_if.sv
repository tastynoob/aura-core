`include "backend_define.svh"

// scu -> csr regs
interface csrrw_if;
    // read channel
    logic access;
    csrIdx_t read_idx;
    logic illegal;
    logic[`XDEF] read_val;
    // write channel
    logic write;
    csrIdx_t write_idx;
    logic[`XDEF] write_val;

    modport m (
        output access,
        output read_idx,
        input illegal,
        input read_val,

        output write,
        output write_idx,
        output write_val
    );

    modport s (
        input access,
        input read_idx,
        output illegal,
        output read_val,

        input write,
        input write_idx,
        input write_val
    );

endinterface

