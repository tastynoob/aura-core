`ifndef __BACKEND_DEFINE_SVH__
`define __BACKEND_DEFINE_SVH__


`include "core_define.svh"

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


typedef intDQEntry_t exeInfo_t;

// typedef struct {
//     ftqIdx_t ftq_idx;
//     robIdx_t rob_idx;
//     irobIdx_t irob_idx; // the immbuffer idx (immOp-only)

//     logic rd_wen;
//     iprIdx_t rdIdx;
//     iprIdx_t rsIdx[`NUMSRCS_INT]; // reg src idx
//     logic use_imm;
//     logic[`WDEF(2)] issueQue_id;
//     MicOp_t::_u micOp_type;
// } exeInfo_t;


typedef struct {
    ftqIdx_t ftq_idx;
    robIdx_t rob_idx;
    irobIdx_t irob_idx;
    logic rd_wen;
    iprIdx_t iprd_idx;
    logic[`XDEF] srcs[`NUMSRCS_INT];

    logic[`WDEF(2)] issueQue_id;
    MicOp_t::_u micOp;
} fuInfo_t;


typedef struct {
    robIdx_t rob_idx;
    irobIdx_t irob_idx;
    logic rd_wen;
    iprIdx_t iprd_idx;
    logic[`XDEF] result;
} valwbInfo_t;


typedef struct {
    robIdx_t rob_idx;
    // for csr/load/store or other
    rv_trap_t::exception except_type;
} exceptwbInfo_t;

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



`endif
