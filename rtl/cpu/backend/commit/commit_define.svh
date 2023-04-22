`ifndef __COMMIT_DEFINE_SVH__
`define __COMMIT_DEFINE_SVH__

`include "core_define.svh"


//commit do something:
// check csr permission
// check exception




typedef struct packed {
    logic is_fpdst; // this dst idx is or not fp regfile idx
    lrIdx_t lrd_idx;
    logic rd_wen;
    prIdx_t prd_idx;
    prIdx_t prev_prd_idx;

    logic complete;
    logic has_exception;
    logic[`XDEF] pc;
    logic[19:0] imm;// we save the inst imm into rob to save space
    //used for debugging
    logic[`XDEF] dst; // this inst's result

} ROBCommitInfo_t;








`endif
