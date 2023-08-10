`ifndef __TILELINK_SVH__
`define __TILELINK_SVH__

`include "base.svh"



package tilelink_enum;
    const logic[`WDEF(3)] Aopcode_get = 4;
    const logic[`WDEF(3)] Aopcode_putf = 0;
    const logic[`WDEF(3)] Aopcode_putp = 1;

    const logic[`WDEF(3)] Dopcode_ack = 0;// access ack
    const logic[`WDEF(3)] Dopcode_ackd = 1;// access ack data
endpackage



`endif
