`ifndef __MEM_DEFINE_SVH__
`define __MEM_DEFINE_SVH__

`include "core_define.svh"


typedef struct packed {
    paddr_t paddr;
    logic dirty;
    logic accessed;
    logic g;
    logic user;
    logic r;
    logic w;
    logic x;
    logic vld;
} pageTableEntry_t;


`endif
