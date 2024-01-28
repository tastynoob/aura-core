`include "backend_define.svh"

// scu -> priv_ctrl/rob
interface syscall_if;
    robIdx_t rob_idx;
    logic mret;
    logic sret;

    logic[`XDEF] npc;

    modport m (
        output rob_idx,
        output mret,
        output sret,
        output npc
    );

    modport s (
        input rob_idx,
        input mret,
        input sret,
        input npc
    );

endinterface





