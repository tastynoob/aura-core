`include "backend_define.svh"





// loadpipe to load/storeQue
interface load2que_if;
    // from loadpipe
    // s0: loadpipe -> loadQue
    // load issue, calculate vaddr
    logic s0_vld;
    lqIdx_t s0_lqIdx;
    logic[`XDEF] s0_vaddr;
    logic[`WDEF(`XLEN/8)] s0_load_vec;
    logic s0_addr_misalign;
    // s1: loadpipe -> loadQue
    // write tlb translate, check tlb or cache miss
    logic s1_vld;
    lqIdx_t s1_lqIdx;
    logic s1_cachemiss;
    logic s1_tlbmiss;
    logic s1_paddr_vld;
    paddr_t s1_paddr;

    // s2: loadpipe -> loadQue
    // check load addr permission
    // storeQue/sbuffer forward check finished
    logic s2_vld;
    lqIdx_t s2_lqIdx;
    logic s2_finished;
    logic s2_except;
    // write back forward data
    logic s2_fwd;
    logic[`WDEF(`XLEN/8)] s2_match_vec;
    logic[`XDEF] s2_fwd_data;


    modport m (
        output s0_lqIdx,
        output s0_vld,
        output s0_vaddr,
        output s0_load_vec,

        output s1_lqIdx,
        output s1_cachemiss,
        output s1_tlbmiss,
        output s1_paddr_vld,
        output s1_paddr,

        output s2_lqIdx,
        output s2_finished,
        output s2_except
    );

    modport s (
        input s0_lqIdx,
        input s0_vld,
        input s0_vaddr,
        input s0_load_vec,

        input s1_lqIdx,
        input s1_cachemiss,
        input s1_tlbmiss,
        input s1_paddr_vld,
        input s1_paddr,

        input s2_lqIdx,
        input s2_finished,
        input s2_except
    );
endinterface


