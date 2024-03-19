`include "backend_define.svh"

// load wake channel
interface loadwake_if;
    logic[`WDEF(`LDU_NUM)] wk;
    iprIdx_t wkIprd[`LDU_NUM];
    lpv_t cl[`LDU_NUM];

    modport m (
        output wk,
        output wkIprd,
        output cl
    );


    modport s (
        input wk,
        input wkIprd,
        input cl
    );

endinterface
