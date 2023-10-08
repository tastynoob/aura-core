
`include "backend_define.svh"




// dispatch to exeBlock
interface disp_if;
    // from/to int block
    logic[`WDEF(`INTDQ_DISP_WID)] disp_int_req;
    logic[`WDEF(`INTDQ_DISP_WID)] disp_int_rdy;
    intDQEntry_t disp_int_info[`INTDQ_DISP_WID];

    // from/to mem block
    logic[`WDEF(`INTDQ_DISP_WID)] disp_mem_req;
    logic[`WDEF(`INTDQ_DISP_WID)] disp_mem_rdy;
    memDQEntry_t disp_mem_info[`INTDQ_DISP_WID];

    modport m (
        output disp_int_req,
        input disp_int_rdy,
        output disp_int_info,

        output disp_mem_req,
        input disp_mem_rdy,
        output disp_int_info
    );

    modport s (
        input disp_int_req,
        output disp_int_rdy,
        input disp_int_info,

        input disp_mem_req,
        output disp_mem_rdy,
        input disp_int_info
    );
endinterface






