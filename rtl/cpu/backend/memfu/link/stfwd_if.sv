


// use virtual addr forward
// use physical addr check
// master: loadpipe
// slave: storeQue/sbuffer

interface stfwd_if;
    // s0: send forward request
    // m->s
    logic s0_vld;
    lqIdx_t s0_lqIdx;  // used for writebackto lq
    sqIdx_t s0_sqIdx;  // store age small than load
    logic [`XDEF] s0_vaddr;
    logic [`WDEF(`XLEN/8)] s0_load_vec;

    // s1: match check
    // m->s
    logic s1_vld;
    paddr_t s1_paddr;
    logic s1_vaddr_match;
    logic s1_data_rdy;  // match and data ready

    // s2: send forward response
    // m<-s
    logic s2_rdy;
    lqIdx_t s2_lqIdx;
    logic s2_paddr_match;
    logic s2_match_failed;
    logic [`WDEF(`XLEN/8)] s2_match_vec;  // which byte was forward matched
    logic [`XDEF] s2_fwd_data;

    modport m(
        output s0_vld,
        output s0_lqIdx,
        output s0_sqIdx,
        output s0_vaddr,
        output s0_load_vec,

        output s1_vld,
        output s1_paddr,
        input s1_vaddr_match,
        input s1_data_rdy,

        input s2_rdy,
        input s2_lqIdx,
        input s2_paddr_match,
        input s2_match_failed,
        input s2_match_vec,
        input s2_fwd_data
    );

    modport s(
        input s0_vld,
        input s0_lqIdx,
        input s0_sqIdx,
        input s0_vaddr,
        input s0_load_vec,

        input s1_vld,
        input s1_paddr,
        output s1_vaddr_match,
        output s1_data_rdy,

        output s2_rdy,
        output s2_lqIdx,
        output s2_paddr_match,
        output s2_match_failed,
        output s2_match_vec,
        output s2_fwd_data
    );

endinterface
