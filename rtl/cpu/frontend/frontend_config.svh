`ifndef __FRONTEND_CONFIG_SVH__
`define __FRONTEND_CONFIG_SVH__


`include "core_define.svh"

/* FTB config */


`define FTB_TAG_WIDTH 11
`define FTB_FALLTHRU_WIDTH ($clog2(`FTB_PREDICT_WIDTH) - 1) //
`define FTB_TARGET_WIDTH 11 // actually is (11+1)

`define FTB_SETS 128
`define FTB_WAYS 4





`endif
