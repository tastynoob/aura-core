


// use virtual addr forward
// use physical addr check
// master: loadpipe
// slave: storeQue/sbuffer
interface stfwd_if;
    // s0: send forward request
    // m->s
    logic s0_vld;
    lqIdx_t s0_lqIdx; // used for writebackto lq
    sqIdx_t s0_sqIdx; // store age small than load
    logic[`XDEF] s0_vaddr;
    logic[`WDEF(`XLEN/8)] s0_load_vec;

    // s1: match check
    // m->s
    logic s1_vld;
    lqIdx_t s1_lqIdx;
    sqIdx_t s1_sqIdx;
    paddr_t s1_paddr;

    // s2: send forward response
    // m<-s
    logic s2_rdy;
    lqIdx_t s2_lqIdx;
    logic s2_match;
    logic s2_data_nrdy; // match but data not ready
    logic[`WDEF(`XLEN/8)] s2_match_vec; // which bit was forward matched
    logic[`XDEF] s2_fwd_data;

    modport m (
        output s0_lqIdx,
        output s0_sqIdx,
        output s0_vaddr,
        output s0_load_vec,

        output s1_vld,
        output s1_lqIdx,
        output s1_sqIdx,
        output s1_paddr,

        input s2_rdy,
        input s2_lqIdx,
        input s2_match,
        input s2_data_nrdy,
        input s2_match_vec,
        input s2_fwd_data
    );

    modport s (
        input s0_lqIdx,
        input s0_sqIdx,
        input s0_vaddr,
        input s0_load_vec,

        input s1_vld,
        input s1_lqIdx,
        input s1_sqIdx,
        input s1_paddr,

        output s2_rdy,
        output s2_lqIdx,
        output s2_match,
        output s2_data_nrdy,
        output s2_match_vec,
        output s2_fwd_data
    );

endinterface
