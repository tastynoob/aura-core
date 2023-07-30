`ifndef __CORE_COMM_SVH__
`define __CORE_COMM_SVH__

`include "core_define.svh"
`include "decode_define.svh"

/******************** branchPredictor define ********************/

package BranchType;
    typedef enum logic[2:0] {
        isCond,
        isDirect,
        isIndirect,
        isCall,
        isRet
    } _;
endpackage


/******************** fetch define ********************/


typedef struct {
    logic[`IDEF] inst;
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic has_except;
    rv_trap_t::exception except;
} fetchEntry_t;



/******************** decode define ********************/

typedef struct {
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic has_except;
    rv_trap_t::exception except;
    logic isRVC;
    logic ismv; //used for mov elim
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
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic has_except;
    rv_trap_t::exception except;
    logic isRVC;
    logic ismv; //used for mov elim
    // different inst use different format,NOTE: csr use imm20 = {3'b0,12'csrIdx,5'zimm}
    logic[`IMMDEF] imm20;
    logic need_serialize; // if is csr write, need to serialize pipeline
    logic rd_wen;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;

    iprIdx_t iprs_idx[`NUMSRCS_INT]; // if has no rs, rs2_idx should be zero
    logic use_imm; //replace the rs2 source to imm
    //which dispQue should go
    logic[`WDEF(2)] dispQue_id;
    //which RS should go
    logic[`WDEF(2)] issueQue_id;

    MicOp_t::_u micOp_type;
} renameInfo_t;


/******************** dispatch define ********************/

typedef struct {
    ftqIdx_t ftq_idx;
    robIdx_t rob_idx;
    irobIdx_t irob_idx;

    logic rd_wen;
    iprIdx_t iprd_idx;
    iprIdx_t iprs_idx[`NUMSRCS_INT];
    logic use_imm;
    logic[`WDEF(2)] issueQue_id;
    MicOp_t::_u micOp_type;
} intDQEntry_t;// to exeIntBlock


/******************** issue define ********************/

//the compressed RS
//in alu:
//select(p0) | deq(p1) | exec(p2) | wb(p3)
// inst | t0 | t1 | t2 | t3 | t4
//  i0  | p0 | p1 | p2 | p3 | ..
//  i1  | .. | p0 | p1 | p2 | p3

typedef struct {
    ftqIdx_t ftq_idx;
    robIdx_t rob_idx;
    irobIdx_t immB_idx; // the immbuffer idx (immOp-only)

    logic[`WDEF(2)] issueQue_id;
    logic rd_wen;
    iprIdx_t rdIdx;
    iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
    logic use_imm;
    MicOp_t::_u micOp_type;
} exeInfo_t;


typedef struct {
    robIdx_t rob_idx;
    irobIdx_t irob_idx;
    logic rd_wen;
    iprIdx_t iprd_idx;
    logic[`XDEF] srcs[`NUMSRCS_INT];

    logic[`WDEF(2)] issueQue_id;
    MicOp_t::_u micOp;
} fuInfo_t;


/******************** writeback define ********************/


typedef struct {
    robIdx_t rob_idx;
    irobIdx_t irob_idx;
    logic rd_wen;
    iprIdx_t iprd_idx;
    logic[`XDEF] result;
} valwbInfo_t;


typedef struct {
    BranchType::_ branch_type;
    robIdx_t rob_idx;
    ftqIdx_t ftq_idx;
    brobIdx_t brob_idx;
    // the branchInst is mispred taken
    logic has_mispred;
    // is branchInst actually taken ? (the jal inst must taken)
    logic branch_taken;
    // branchInst's pc
    logic[`XDEF] branch_pc;
    // branchInst's taken pc
    logic[`XDEF] branch_npc;
} branchwbInfo_t;// writeback to rob and ftq



typedef struct {
    robIdx_t rob_idx;
    // for csr/load/store or other
    rv_trap_t::exception except_type;
} exceptwbInfo_t;

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


typedef struct packed {
    // trap info
    logic interrupt_vectored;
    logic[1:0] level;
    logic[`XDEF] status;
    logic[`XDEF] tvec;
} csr_in_pack_t;

typedef struct packed {
    // trap handle
    logic has_trap;
    logic[`XDEF] epc;
    logic[`XDEF] cause;
    logic[`XDEF] tval;
    logic[`IDEF] tinst;
    logic[`IDEF] tval2;
    //
} csr_out_pack_t;

typedef struct {
    ftqIdx_t ftq_idx;
    // to rename
    logic isRVC;
    logic ismv;
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;
} ROBEntry_t;

typedef struct {
    //to rename
    logic ismv;
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;
} renameCommitInfo_t;


typedef struct {
    logic dueToBranch;
    logic branch_taken;
    logic[`XDEF] arch_pc;
} squashInfo_t;


`endif
