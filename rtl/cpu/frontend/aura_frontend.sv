




// cpu frontend
// storage <-tilelink-> frontend <--> backend




module aura_frontend (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from backend
    input wire[`WDEF(`BRU_NUM)] i_branchwb_vld,
    input branchwbInfo_t i_branchwbInfo[`BRU_NUM],

    input ftqIdx_t i_read_ftqIdx[`BRU_NUM],
    output wire[`XDEF] o_read_ftqStartAddr[`BRU_NUM],
    output wire[`XDEF] o_read_ftqNextAddr[`BRU_NUM],

    // to backend
    input wire i_backend_rdy,
    output wire[`WDEF(`FETCH_WIDTH)] o_fetch_inst_vld,
    output fetchEntry_t o_fetch_inst[`FETCH_WIDTH],

    input wire i_commit_vld,
    input ftqIdx_t i_commit_ftqIdx,


    // to next level storage
    tilelink_if.m if_fetch_bus
);



    core2icache_if if_toIcache();

    fetcher u_fetcher(
        .clk                 ( clk                 ),
        .rst                 ( rst                 ),
        .i_squash_vld        ( i_squash_vld        ),
        .i_squashInfo        ( i_squashInfo         ),

        .i_branchwb_vld      ( i_branchwb_vld        ),
        .i_branchwbInfo      ( i_branchwbInfo         ),

        .i_read_ftqIdx       ( i_read_ftqIdx         ),
        .o_read_ftqStartAddr ( o_read_ftqStartAddr         ),
        .o_read_ftqNextAddr  ( o_read_ftqNextAddr         ),

        .i_backend_rdy       ( i_backend_rdy        ),
        .o_fetch_inst_vld    ( o_fetch_inst_vld         ),
        .o_fetch_inst        ( o_fetch_inst         ),

        .i_commit_vld        ( i_commit_vld        ),
        .i_commit_ftqIdx     ( i_commit_ftqIdx         ),

        .if_core_fetch       ( if_toIcache )
    );

    icache
    #(
        .BANKS ( 1  ),
        .SETS  ( 32 ),
        .WAYS  ( 4  )
    )
    u_icache(
        .clk           ( clk         ),
        .rst           ( rst         ),
        .if_core_fetch ( if_toIcache )
    );




endmodule



