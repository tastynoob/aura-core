`include "backend_define.svh"





interface load2dcache_if;
    // s0:
    // send request, read tag sram, translate vaddr
    logic s0_req;
    logic s0_gnt;
    lqIdx_t s0_lqIdx;
    logic[`XDEF] s0_vaddr;

    // s1:
    // check dcache/tlb miss
    logic s1_req;
    logic s1_rdy;// used for pipeline align
    logic s1_conflict; // data bank conflict
    logic s1_tlbhit; // tlb translate finished
    logic s1_addrMisaligned;// tlb check
    logic s1_cachehit;
    paddr_t s1_paddr; // translated paddr

    // s2:
    logic s2_req;
    logic s2_rdy;
    logic s2_has_except;
    rv_trap_t::exception s2_except;
    logic s2_data_vld;
    logic[`WDEF(`CACHELINE_SIZE*8)] s2_data;

    modport m (
        output s0_req,
        input s0_gnt,
        output s0_lqIdx,
        output s0_vaddr,
        output s0_load_vec,

        output s1_req,
        input s1_rdy,
        input s1_conflict,
        input s1_tlbhit,
        input s1_cachehit,
        input s1_paddr,

        output s2_req,
        input s2_rdy,
        input s2_has_except,
        input s2_except,
        input s2_data_vld,
        input s2_data
    );

    modport s (
        input  s0_req,
        output s0_gnt,
        input  s0_lqIdx,
        input  s0_vaddr,
        input  s0_load_vec,

        input  s1_req,
        output s1_rdy,
        output s1_conflict,
        output s1_tlbhit,
        output s1_cachehit,
        output s1_paddr,

        input  s2_req,
        output s2_rdy,
        output s2_has_except,
        output s2_except,
        input  s2_data_vld,
        input  s2_data
    );
endinterface

