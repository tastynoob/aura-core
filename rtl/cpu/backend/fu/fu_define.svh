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
    logic rd_vld;
    iprIdx_t rd_idx;
    logic[`XDEF] rd_data;
} bypassPort_t;




`endif

