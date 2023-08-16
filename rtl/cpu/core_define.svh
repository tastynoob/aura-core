`ifndef __CORE_DEFINE_SVH__
`define __CORE_DEFINE_SVH__

`include "core_config.svh"
`include "decode_define.svh"

package BranchType;
    typedef enum logic[2:0] {
        isCond,
        isDirect,
        isIndirect,
        isCall,
        isRet
    } _;
endpackage


typedef struct packed{
    logic[`IDEF] inst;
    ftqIdx_t ftq_idx;
    ftqOffset_t ftqOffset;
    logic has_except;
    rv_trap_t::exception except;
} fetchEntry_t;


typedef struct {
    BranchType::_ branch_type;
    robIdx_t rob_idx;
    ftqIdx_t ftq_idx;
    brobIdx_t brob_idx;
    // the branchInst is mispred taken
    logic has_mispred;
    // is branchInst actually taken ? (the jal inst must taken)
    logic branch_taken;
    // branchInst's fallthruOffset
    ftqOffset_t fallthruOffset;
    // branchInst's taken pc
    logic[`XDEF] target_pc;
    // branchInst's nextpc
    logic[`XDEF] branch_npc;
} branchwbInfo_t;// writeback to rob and ftq


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
    logic dueToBranch;
    logic branch_taken;
    logic[`XDEF] arch_pc;
} squashInfo_t;


`endif
