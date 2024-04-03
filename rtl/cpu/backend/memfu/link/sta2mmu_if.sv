`include "backend_define.svh"



interface sta2mmu_if;
    logic s0_req;
    logic [`XDEF] s0_vaddr;

    logic s1_miss;// tlb miss
    logic s1_pagefault;// store page fault
    logic s1_illegaAddr;// store illegal address
    logic s1_mmio;// store mmio
    paddr_t s1_paddr;
    modport m(
        output s0_req,
        output s0_vaddr,

        input s1_miss,
        input s1_pagefault,
        input s1_illegaAddr,
        input s1_mmio,
        input s1_paddr
    );

    modport s (
        input s0_req,
        input s0_vaddr,

        output s1_miss,
        output s1_pagefault,
        output s1_illegaAddr,
        output s1_mmio,
        output s1_paddr
    );
endinterface
