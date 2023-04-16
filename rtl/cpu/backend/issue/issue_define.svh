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
    logic src1_ready;
    logic src0_ready;
    logic[`XDEF] src0;//if src is not ready, it will be replaced to src regIdx
    logic[`XDEF] src1;
    iprIdx_t rdIdx;
    Fu_t::_ fu_type;
    MicOp_t::_u micOp_type;
} RSenqInfo_t;

typedef struct packed {
    logic src0_bypass;//need get data from byoass network
    logic src1_bypass;
    logic[`XDEF] src0;//if src is not ready, it will be replaced to src regIdx
    logic[`XDEF] src1;
    iprIdx_t rdIdx;
    Fu_t::_ fu_type;
    MicOp_t::_u micOp_type;
} RSdeqInfo_t;

typedef struct packed {
    logic vld;//may be unused in compressed RS
    logic src0_ready;
    logic src1_ready;
    logic[`XDEF] src0;//if src is not ready, it will be replaced to src regIdx
    logic[`XDEF] src1;
    iprIdx_t rdIdx;
    logic[3:0] wakeup_delay;//TODO: finish delay wakeup
    Fu_t::_ fu_type;
    MicOp_t::_u micOp_type;
} RSInfo_t;

/*********************/


`endif


