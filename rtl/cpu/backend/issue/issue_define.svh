`ifndef __ISSUE_DEFINE_SVH__
`define __ISSUE_DEFINE_SVH__

`include "core_define.svh"
`include "decode_define.svh"

/*********************/

//the compressed RS
//in alu:
//select(p0) | deq(p1) | exec(p2) | wb(p3)
// inst | t0 | t1 | t2 | t3 | t4
//  i0  | p0 | p1 | p2 | p3 | ..
//  i1  | .. | p0 | p1 | p2 | p3


typedef struct packed {
    iprIdx_t rdIdx;
    iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
    immBIdx_t immB_idx; // the immbuffer idx (immOp-only)
    branchBIdx_t pcB_idx; // the pcbuffer idx (bru-only)
    logic use_imm;
    robIdx_t rob_idx;
    MicOp_t::_u micOp_type;
} RSenqInfo_t;

typedef struct packed {
    iprIdx_t rdIdx;
    iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
    immBIdx_t immB_idx; // the immbuffer idx (immOp-only)
    branchBIdx_t pcB_idx; // the pcbuffer idx (bru-only)
    logic use_imm;

    robIdx_t rob_idx;
    MicOp_t::_u micOp_type;
} RSdeqInfo_t;

typedef struct packed {
    logic vld; //unused in compressed RS
    logic issued; // flag issued
    logic spec_wakeup; // flag spec wakeup
    logic[`WDEF(`NUMSRCS_INT)] src_rdy; // which src is ready
    logic[`WDEF(`NUMSRCS_INT)] src_spec_rdy; // which src is speculative ready

    logic rd_wen;
    iprIdx_t rdIdx;
    iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
    immBIdx_t immB_idx; // the immbuffer idx (immOp-only)
    branchBIdx_t pcB_idx; // the pcbuffer idx (bru-only)
    logic use_imm; // if use imm, the rsIdx[1] will be replaced to immBuffer idx

    robIdx_t rob_idx;
    MicOp_t::_u micOp_type;
} RSEntry_t;


/*********************/


`endif


