`include "core_define.svh"
`include "backend_define.svh"







module aura_core (
    input wire clk,
    input wire rst,

    // tilelink 0
    tilelink_if.m if_tilelink_bus0,
    // tilelink 1
    tilelink_if.m if_tilelink_bus1
);


    wire squash_vld;
    squashInfo_t squashInfo;

    wire[`WDEF(`BRU_NUM)] branchwb_vld;
    branchwbInfo_t branchwb_info[`BRU_NUM];
    ftqIdx_t read_ftqIdx[`BRU_NUM];
    wire[`XDEF] read_ftqStartAddr[`BRU_NUM];
    wire[`XDEF] read_ftqNextAddr[`BRU_NUM];
    wire backend_stall;
    wire[`WDEF(`FETCH_WIDTH)] fetch_inst_vld;
    fetchEntry_t fetch_inst[`FETCH_WIDTH];

    wire commit_ftq_vld;
    ftqIdx_t commit_ftqIdx;

    aura_frontend u_aura_frontend(
        .clk                 ( clk               ),
        .rst                 ( rst               ),

        .i_squash_vld        ( squash_vld        ),
        .i_squashInfo        ( squashInfo        ),

        .i_branchwb_vld      ( branchwb_vld      ),
        .i_branchwbInfo      ( branchwb_info    ),

        .i_read_ftqIdx       ( read_ftqIdx       ),
        .o_read_ftqStartAddr ( read_ftqStartAddr ),
        .o_read_ftqNextAddr  ( read_ftqNextAddr  ),

        .i_backend_stall     ( backend_stall    ),
        .o_fetch_inst_vld    ( fetch_inst_vld    ),
        .o_fetch_inst        ( fetch_inst        ),

        .i_commit_vld        ( commit_ftq_vld  ),
        .i_commit_ftqIdx     ( commit_ftqIdx     ),

        .if_fetch_bus        ( if_tilelink_bus0  )
    );


    aura_backend u_aura_backend(
        .clk                 ( clk                 ),
        .rst                 ( rst                 ),

        .o_squash_vld        ( squash_vld        ),
        .o_squashInfo        ( squashInfo        ),

        .o_branchwb_vld      ( branchwb_vld      ),
        .o_branchwbInfo      ( branchwb_info    ),

        .o_read_ftqIdx       ( read_ftqIdx       ),
        .i_read_ftqStartAddr ( read_ftqStartAddr ),
        .i_read_ftqNextAddr  ( read_ftqNextAddr  ),

        .o_stall             ( backend_stall             ),
        .i_inst_vld          ( fetch_inst_vld          ),
        .i_inst              ( fetch_inst             ),

        .o_commit_ftq_vld    ( commit_ftq_vld        ),
        .o_commit_ftqIdx     ( commit_ftqIdx     )
    );








endmodule












