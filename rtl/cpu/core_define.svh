`ifndef __CORE_DEFINE_SVH__
`define __CORE_DEFINE_SVH__

`include "core_config.svh"
`include "decode_define.svh"

package BranchType;
    typedef enum logic [2:0] {
        isNone = 0,
        isCond,
        isDirect,
        isIndirect,
        isCall,
        isRet
    } _;
endpackage


typedef struct packed {
    logic [`IDEF] inst;
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic [`WDEF(`MEMDEP_FOLDPC_WIDTH)] foldpc;
    logic has_except;
    rv_trap_t::exception except;
    logic [`XDEF] instmeta;
} fetchEntry_t;


typedef struct {
    BranchType::_ branch_type;
    robIdx_t rob_idx;
    ftqIdx_t ftq_idx;
    // the branchInst is mispred taken
    logic has_mispred;
    // is branchInst actually taken ? (the jal inst must taken)
    logic branch_taken;
    // branchInst's fallthruOffset
    // NOTE: fallthruOffset may >= FTB_PREDICT_WIDTH
    logic [`WDEF($clog2(`FTB_PREDICT_WIDTH) + 1)] fallthruOffset;
    // branchInst's taken pc
    logic [`XDEF] target_pc;
    // branchInst's nextpc
    logic [`XDEF] branch_npc;
} branchwbInfo_t;  // writeback to rob and ftq


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
    logic dueToBranch;
    logic dueToViolation;
    logic branch_taken;
    logic [`XDEF] arch_pc;

    // violation info
    logic [`WDEF(`MEMDEP_FOLDPC_WIDTH)] stpc;
    logic [`WDEF(`MEMDEP_FOLDPC_WIDTH)] ldpc;
} squashInfo_t;


`endif
