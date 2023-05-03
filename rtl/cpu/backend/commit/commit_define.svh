`ifndef __COMMIT_DEFINE_SVH__
`define __COMMIT_DEFINE_SVH__

`include "core_define.svh"


//commit do something:
// check csr permission
// check exception
// use spec-arch to restore core status



typedef struct packed {
    //to rename
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;

    //rename restore(branch mispred)
    //flush pipeline
    logic restore_vld;
} renameCommitInfo_t;



typedef struct packed {
    //bpu update
    logic branch_taken;
    logic[`XDEF] branch_pc;

    //restore bpu(branch mispred)
    logic restore_vld;
    logic[`XDEF] restore_pc;
} branchCommitInfo_t;




`endif
