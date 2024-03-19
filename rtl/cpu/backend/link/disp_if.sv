
`include "backend_define.svh"




// dispatch -> exeBlock
interface disp_if;
    // req -> exeBlock
    // rdy -> dispatch

    // from/to int block
    logic [`WDEF(`INTDQ_DISP_WID)] int_req;
    logic [`WDEF(`INTDQ_DISP_WID)] int_rdy;
    microOp_t int_info[`INTDQ_DISP_WID];

    // from/to mem block
    logic [`WDEF(`MEMDQ_DISP_WID)] mem_req;
    logic [`WDEF(`MEMDQ_DISP_WID)] mem_rdy;
    microOp_t mem_info[`MEMDQ_DISP_WID];

    modport m(output int_req, input int_rdy, output int_info, output mem_req, input mem_rdy, output mem_info);

    modport s(input int_req, output int_rdy, input int_info, input mem_req, output mem_rdy, input mem_info);
endinterface






