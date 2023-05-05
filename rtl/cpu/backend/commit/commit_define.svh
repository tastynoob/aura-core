`ifndef __COMMIT_DEFINE_SVH__
`define __COMMIT_DEFINE_SVH__

`include "core_define.svh"
`include "fu_define.svh"

//commit do something:
// check csr permission
// check exception
// use spec-arch to restore core status

typedef struct packed {
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;
} ROBEntry_t;


typedef struct packed {
    //to rename
    logic has_rd;
    ilrIdx_t ilrd_idx;
    iprIdx_t iprd_idx;
    iprIdx_t prev_iprd_idx;

} renameCommitInfo_t;



typedef struct packed {
    //bpu update
    logic branch_taken;
    logic[`XDEF] branch_pc;

    //restore bpu(branch mispred)
    logic[`XDEF] resteer_pc;
} branchCommitInfo_t;




`endif
