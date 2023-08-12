




// cpu frontend
// storage <-tilelink-> frontend <--> backend




module aura_frontend (
    input wire clk,
    input wire rst,

    // to next level storage
    tilelink_if.m if_fetch_bus
);



    core2icache_if if_toIcache;

    fetcher u_fetcher(
        .clk                 ( clk                 ),
        .rst                 ( rst                 ),
        .i_squash_vld        ( 0        ),
        .i_squashInfo        (          ),
        .i_branchwb_vld      ( 0        ),
        .i_branchwbInfo      (          ),
        .i_read_ftqIdx       (          ),
        .o_read_ftqStartAddr (          ),
        .o_read_ftqNextAddr  (          ),
        .i_backend_rdy       ( 0        ),
        .o_fetch_inst_vld    (          ),
        .o_fetch_inst        (          ),
        .i_commit_vld        ( 0        ),
        .i_commit_ftqIdx     (          ),
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



