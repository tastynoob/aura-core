`ifndef __CORE_CONFIG_SVH__
`define __CORE_CONFIG_SVH__

`include "core_comm.svh"


`define FETCH_WIDTH `FTB_PREDICT_WIDTH/2

// decode rename
`define DECODE_WIDTH 4
`define RENAME_WIDTH `DECODE_WIDTH

`define ENABLE_MEMPRED 1

`define STORE_ISSUE_WIDTH 2

// commit
`define COMMIT_WIDTH 4


`endif

