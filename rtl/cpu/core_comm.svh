`ifndef __CORE_COMM_SVH__
`define __CORE_COMM_SVH__

`include "core_define.svh"
`include "decode_define.svh"

/******************** decode define ********************/

typedef struct {
    logic isRVC;
    logic ismv; //used for mov elim
    logic[`XDEF] npc;// next inst's pc
    // different inst use different format,NOTE: csr use imm20 = {3'b0,12'csrIdx,5'zimm}
    logic[`IMMDEF] imm20;
    logic need_serialize; // if is csr write, need to serialize pipeline
    logic rd_wen;
    ilrIdx_t ilrd_idx;
    ilrIdx_t ilrs_idx[`NUMSRCS_INT]; // if has no rs, rs2_idx should be zero
    logic use_imm; //replace the rs2 source to imm
    //which dispQue should go
    logic[`WDEF(2)] dispQue_id;
    //which IQ should go
    logic[`WDEF(2)] issueQue_id;

    MicOp_t::_u micOp_type;
}decInfo_t;

/******************** rename define ********************/

//move elim
//li x1,1
//li x2,1
//add x1,x1,x2
//add x2,x1,x2
//mv x2,x1
//add x1,x1,x2
//after rename
//li p1,1       ;p1:1
//li p2,1       ;p2:1
//add p3,p1,p2  ;p3:1
//add p4,p3,p2  ;p4:1
//mv p3,p3      ;p3:2
//add p5,p3,p4  ;p5:1

typedef struct {
    logic isRVC;
    logic ismv; //used for mov elim
    logic[`XDEF] pc;
    logic[`XDEF] npc;
    ilrIdx_t ilrd_idx;
    iprIdx_t prev_iprd_idx;
    // different inst use different format,NOTE: csr use imm20 = {3'b0,12'csrIdx,5'zimm}
    logic[`IMMDEF] imm20;
    logic need_serialize; // if is csr write, need to serialize pipeline
    logic rd_wen;
    iprIdx_t iprd_idx;
    iprIdx_t iprs_idx[`NUMSRCS_INT]; // if has no rs, rs2_idx should be zero
    logic use_imm; //replace the rs2 source to imm
    //which dispQue should go
    logic[`WDEF(2)] dispQue_id;
    //which RS should go
    logic[`WDEF(2)] dispRS_id;

    MicOp_t::_u micOp_type;
} renameInfo_t;


/******************** dispatch define ********************/

// TODO: we may need to implement pcbuffer and immbuffer

typedef struct packed {
    logic[`XDEF] pc;
    logic[`XDEF] npc;
} pc_and_npc_t;

typedef struct {
    logic rd_wen;
    iprIdx_t iprd_idx;
    iprIdx_t iprs_idx[`NUMSRCS_INT];
    logic use_imm;
    logic[`WDEF(2)] dispRS_id;
    robIdx_t robIdx;
    immBIdx_t immBIdx;
    branchBIdx_t branchBIdx;
    MicOp_t::_u micOp_type;
} intDQEntry_t;


/******************** issue define ********************/

//the compressed RS
//in alu:
//select(p0) | deq(p1) | exec(p2) | wb(p3)
// inst | t0 | t1 | t2 | t3 | t4
//  i0  | p0 | p1 | p2 | p3 | ..
//  i1  | .. | p0 | p1 | p2 | p3


typedef struct {
    iprIdx_t rdIdx;
    iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
    immBIdx_t immB_idx; // the immbuffer idx (immOp-only)
    branchBIdx_t pcB_idx; // the pcbuffer idx (bru-only)
    logic use_imm;
    robIdx_t rob_idx;
    MicOp_t::_u micOp_type;
} RSenqInfo_t;

typedef struct {
    iprIdx_t rdIdx;
    iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
    immBIdx_t immB_idx; // the immbuffer idx (immOp-only)
    branchBIdx_t pcB_idx; // the pcbuffer idx (bru-only)
    logic use_imm;

    robIdx_t rob_idx;
    MicOp_t::_u micOp_type;
} RSdeqInfo_t;

typedef struct {
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


/******************** writeback define ********************/


typedef struct {
    logic rd_wen;
    iprIdx_t iprd_idx;
    logic[`XDEF] result;
} commWBInfo_t;

typedef struct {
    // the branchInst is mispred taken
    logic has_mispred;
    // is branchInst taken ? (the jal inst must taken)
    logic branch_taken;
    // branchInst's pc
    logic[`XDEF] branch_pc;
    // branchInst's taken pc
    logic[`XDEF] branch_npc;
} branchWBInfo_t;


/******************** commit define ********************/

// DESIGN:
// only when branch retired, rob can send squashInfo
// and squashInfo priority is greater than commitInfo
// when squashed
// set the spec-status to arch-status

// commit do something:
// check csr permission
// check exception
// use spec-arch to restore core status

typedef struct {
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;
    branchBIdx_t branchBIdx;
} ROBEntry_t;

typedef struct {
    //to rename
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;
} renameCommitInfo_t;

typedef struct {
    // bpu update
    // is branchInst taken ? (the jal inst must taken)
    logic branch_taken;
    // branchInst's pc
    logic[`XDEF] branch_pc;
    // branchInst's npc (real taken pc)
    logic[`XDEF] branch_npc;
} branchCommitInfo_t;


typedef struct {
    logic dueToBranch;
    logic dueToMemOrder;
    logic[`XDEF] arch_pc;
} squashInfo_t;


`endif
