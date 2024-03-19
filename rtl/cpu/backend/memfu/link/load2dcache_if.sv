`include "backend_define.svh"


/*

| agu | get paddr, ptag | get data |
   |          |
   V        match?
 vaddr        V
           s1_miss

*/


interface load2dcache_if;
    // s0:
    // send request, read tag sram, translate vaddr
    logic s0_req;
    logic s0_gnt;
    lqIdx_t s0_lqIdx;
    logic [`XDEF] s0_vaddr;

    // s1:
    // check dcache/tlb miss
    logic s1_req;
    logic s1_rdy;  // used for pipeline align
    logic s1_cft;  // bank conflict, replay
    logic s1_miss;  // tlbmiss or cache miss
    logic s1_pagefault;  // mmu page fault
    logic s1_illegaAddr;  // mmu check failed
    logic s1_mmio;  // mmio space
    paddr_t s1_paddr;  // translated paddr

    // s2:
    logic s2_req;
    logic s2_rdy;
    logic [`WDEF(`CACHELINE_SIZE*8)] s2_data;  // return one cacheline

    modport m(
        output s0_req,
        input s0_gnt,
        output s0_lqIdx,
        output s0_vaddr,

        output s1_req,
        input s1_rdy,
        input s1_cft,
        input s1_miss,
        input s1_pagefault,
        input s1_illegaAddr,
        input s1_mmio,
        input s1_paddr,

        output s2_req,
        input s2_rdy,
        input s2_data
    );

    modport s(
        input s0_req,
        output s0_gnt,
        input s0_lqIdx,
        input s0_vaddr,

        input s1_req,
        output s1_rdy,
        output s1_cft,
        output s1_miss,
        output s1_pagefault,
        output s1_illegaAddr,
        output s1_mmio,
        output s1_paddr,

        input s2_req,
        output s2_rdy,
        output s2_data
    );
endinterface

