`ifndef __BACKEND_DEFINE_SVH__
`define __BACKEND_DEFINE_SVH__

`include "core_define.svh"

// can not change

`define NUMSRCS_INT 2

// dispatch
`define INTDQ_DISP_WID 4
`define MEMDQ_DISP_WID 4

`define INTBLOCK_ID 0
`define MEMBLOCK_ID 1
`define FLTBLOCK_ID 2
`define UNKOWNBLOCK_ID 3

`define ALUIQ_ID 0
`define BRUIQ_ID 1
`define MDUIQ_ID 2
`define SCUIQ_ID 3
`define LDUIQ_ID 4
`define STUIQ_ID 5

`define ALU_NUM 4
`define BRU_NUM 2
`define MDU_NUM 2

`define LDU_NUM 2
`define STU_NUM 2

// immBuffer read port
// 4 alu + 2 ld + 2 sta
`define IMMBUFFER_READPORT_NUM (`ALU_NUM + `LDU_NUM + `STU_NUM)
`define IMMBUFFER_CLEARPORT_NUM `IMMBUFFER_READPORT_NUM
`define IMMBUFFER_COMMIT_WID 8

// 6
`define INT_COMPLETE_NUM (`ALU_NUM + `MDU_NUM)
// 4
`define MEM_COMPLETE_NUM (`LDU_NUM + `STU_NUM)
// 10
`define COMPLETE_NUM (`ALU_NUM + `MDU_NUM + `LDU_NUM + `STU_NUM)
// 6
`define INT_WBPORT_NUM (`ALU_NUM + `MDU_NUM)
// 2
`define MEM_WBPORT_NUM (`LDU_NUM)
// 8
`define WBPORT_NUM (`ALU_NUM + `MDU_NUM + `LDU_NUM)

`define INT_SWAKE_WIDTH (`ALU_NUM + `MDU_NUM)
`define MEM_SWAKE_WIDTH `LDU_NUM

// 12 = 6 int specwakechannel + 8 wbwakechannel, NOTE: load specwake use loadwake_if
`define INTWAKE_WIDTH (`INT_SWAKE_WIDTH + `WBPORT_NUM)
// 14 = 2 mem specwakechannel + 6 int specwakechannel + 8
`define MEMWAKE_WIDTH (`MEM_SWAKE_WIDTH + `INT_SWAKE_WIDTH + `WBPORT_NUM)
// 2 stage issue + 1 stage writeback
// loadpipe no bypass channel
`define BYPASS_WIDTH (`INT_WBPORT_NUM * 2 + `WBPORT_NUM)

`define MAX_ISSUEQUE_SIZE 64
typedef logic [`WDEF($clog2(`MAX_ISSUEQUE_SIZE))] iqIdx_t;

// load position vec
`define LPV_WIDTH 3
`define LPV_INIT 3'b001
typedef logic [`WDEF(`LPV_WIDTH * `LDU_NUM )] lpv_t;

typedef struct {
    logic [`WDEF(`MEMDEP_FOLDPC_WIDTH)] foldpc;
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic has_except;
    rv_trap_t::exception except;
    logic isRVC;
    logic ismv;  //used for mov elim
    // different inst use different format,NOTE: csr use imm20 = {3'b0,12'csrIdx,5'zimm}
    logic [`IMMDEF] imm20;
    logic need_serialize;  // if is csr write, need to serialize pipeline
    logic rd_wen;
    ilrIdx_t ilrd_idx;
    ilrIdx_t ilrs_idx[`NUMSRCS_INT];  // if has no rs, rs2_idx should be zero
    logic use_imm;  //replace the rs2 source to imm
    //which dispQue should go
    logic [`WDEF(2)] dispQue_id;
    //which IQ should go
    logic [`WDEF(3)] issueQue_id;
    MicOp_t::_u micOp_type;
    logic isStore;

    logic [`XDEF] instmeta;
} decInfo_t;

typedef struct {
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic has_except;
    rv_trap_t::exception except;
    logic isRVC;
    logic ismv;  //used for mov elim
    // different inst use different format,NOTE: csr use imm20 = {3'b0,12'csrIdx,5'zimm}
    logic [`IMMDEF] imm20;
    logic need_serialize;  // if is csr write, need to serialize pipeline
    logic rd_wen;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;

    iprIdx_t iprs_idx[`NUMSRCS_INT];  // if has no rs, rs2_idx should be zero
    logic use_imm;  //replace the rs2 source to imm
    //which dispQue should go
    logic [`WDEF(2)] dispQue_id;
    //which RS should go
    logic [`WDEF(3)] issueQue_id;
    MicOp_t::_u micOp_type;
    logic isStore;

    logic [`XDEF] instmeta;
} renameInfo_t;

typedef struct {
    // pointer
    ftqIdx_t ftqIdx;
    robIdx_t robIdx;
    irobIdx_t irobIdx;
    lqIdx_t lqIdx;
    sqIdx_t sqIdx;
    // ctrl
    logic rdwen;
    iprIdx_t iprd;
    iprIdx_t iprs[`NUMSRCS_INT];
    logic useImm;
    logic [`WDEF(3)] issueQueId;
    MicOp_t::_u micOp;
    // memdep
    logic shouldwait;
    robIdx_t depIdx;

    logic [`XDEF] seqNum;
} microOp_t;

typedef struct {
    // pointer
    ftqIdx_t ftqIdx;
    robIdx_t robIdx;
    irobIdx_t irobIdx;
    lqIdx_t lqIdx;
    sqIdx_t sqIdx;
    // ctrl
    logic rdwen;
    iprIdx_t iprd;
    iprIdx_t iprs[`NUMSRCS_INT];
    logic useImm;
    logic [`WDEF(3)] issueQueId;
    MicOp_t::_u micOp;
    // issue states
    iqIdx_t iqIdx;

    logic [`XDEF] seqNum;
} issueState_t;

typedef struct {
    // pointer
    ftqIdx_t ftqIdx;
    robIdx_t robIdx;
    irobIdx_t irobIdx;
    lqIdx_t lqIdx;
    sqIdx_t sqIdx;
    // ctrl
    logic rdwen;
    iprIdx_t iprd;
    logic useImm;
    logic [`WDEF(3)] issueQueId;
    MicOp_t::_u micOp;
    // data
    logic [`XDEF] srcs[`NUMSRCS_INT];
    imm_t imm20;
    ftqOffset_t ftqOffset;
    logic [`XDEF] pc;
    logic [`XDEF] npc;
    iqIdx_t iqIdx;  // load only

    logic [`XDEF] seqNum;
} exeInfo_t;

typedef struct {robIdx_t rob_idx;} loadQueEntry_t;

typedef struct {
    robIdx_t rob_idx;
    irobIdx_t irob_idx;
    logic use_imm;
    logic rd_wen;
    iprIdx_t iprd_idx;
    logic [`XDEF] result;
} comwbInfo_t;

typedef struct {
    robIdx_t rob_idx;
    // for csr/load/store or other
    rv_trap_t::exception except_type;
    logic [`XDEF] stpc;
    logic [`XDEF] ldpc;
} exceptwbInfo_t;

typedef struct {
    ftqIdx_t ftq_idx;
    // to rename
    logic isRVC;
    logic isLoad;
    logic isStore;
    logic ismv;
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;
    logic serialized;

    logic [`XDEF] instmeta;
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
    logic vld;
    logic [`XDEF] npc;
    robIdx_t robIdx;
} reExecInfo_t;


typedef struct {
    logic violation;
    logic [`XDEF] stpc;
    logic [`XDEF] ldpc;
} memvioInfo_t;

// DESIGN:
// if:
// i1 (alu0 if (!replay) wakeOthers ) | i2 (alu1) | e1(div stall) | ... | writeback
// only replay alu0
// div will writeback at n (n > 2) tick
// alu1 will writeback at 2 tick
// so alu1 can execute parallel with div



`endif
