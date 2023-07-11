`ifndef __FU_DEFINE_SVH__
`define __FU_DEFINE_SVH__

`include "core_define.svh"
`include "issue_define.svh"

// DESIGN
// we can calcuate the bypass idx in readfile stage
// and get the bypassed data at exec0 stage
// alu must support execute back to back
// mdu actually can delay 1 cycle bypass to alu


`define WB_WIDTH 6

typedef struct packed {
    robIdx_t robIdx;
    logic use_imm;
    irobIdx_t immBIdx;
    logic is_branch;
    brobIdx_t brob_idx;
    logic iprd_wen;
    iprIdx_t iprd_idx;
    MicOp_t::_u micOp;
} fuInfo_t;


typedef struct packed {
    robIdx_t robIdx;
    logic use_imm;
    irobIdx_t immBIdx;// used for immOp
    logic is_branch;
    brobIdx_t brob_idx;// used for branch
    logic iprd_wen;
    iprIdx_t iprd_idx;
    logic[`XDEF] wb_data;
} wbInfo_t;




`endif

