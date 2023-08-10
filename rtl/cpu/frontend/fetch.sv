`include "frontend_define.svh"




// backend may read/write some info from frontend
// one instruction pc used for branch and trap
// branch writeback info: branch offset in ftq, branch target pc, branch mispred, branch taken



module fetch (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,


    // from backend
    input ftqIdx_t i_read_ftqIdx[`BRU_NUM],
    output wire[`XDEF] o_read_ftqStartAddr,
    output wire[`XDEF] o_read_ftqNextAddr,

    // to backend
    input wire i_backend_rdy,
    output wire[`WDEF(`FETCH_WIDTH)] o_fetch_inst_vld,
    output fetchEntry_t o_fetch_inst[`FETCH_WIDTH],

    input wire i_commit_vld,
    input ftqIdx_t i_commit_ftqIdx,

    // to icache
    core2icache_if.m if_core_fetch

);



    wire toBPU_update_vld;
    wire toFTQ_update_finished;
    BPupdateInfo_t toBPU_updateInfo;

    wire toBPU_ftq_rdy;
    wire toFTQ_pred_vld;
    ftqInfo_t toFTQ_pred_ftqInfo;
    BPU u_BPU(
        .clk               ( clk               ),
        .rst               ( rst               ),
        .i_squash_vld      ( i_squash_vld      ),
        .i_squashInfo      ( i_squashInfo      ),

        .i_update_vld      ( toBPU_update_vld      ),
        .o_update_finished ( toFTQ_update_finished ),
        .i_BPupdateInfo    ( toBPU_updateInfo    ),

        .i_ftq_rdy         ( toBPU_ftq_rdy         ),
        .o_pred_vld        ( toFTQ_pred_vld        ),
        .o_pred_ftqInfo    ( toFTQ_pred_ftqInfo    )
    );


    FTQ u_FTQ(
        .clk                    ( clk                    ),
        .rst                    ( rst                    ),

        .i_squash_vld           ( i_squash_vld           ),
        .i_squashInfo           ( i_squashInfo           ),

        .i_pred_req             ( toFTQ_pred_vld             ),
        .o_ftq_rdy              ( toBPU_ftq_rdy              ),
        .i_pred_ftqInfo         ( toFTQ_pred_ftqInfo         ),

        .o_bpu_update           ( toBPU_update_vld           ),
        .i_bpu_update_finished  ( toFTQ_update_finished  ),
        .o_BPUupdateInfo        ( toBPU_updateInfo        ),

        .o_icache_fetch_req     (     ),
        .i_icache_fetch_rdy     ( 0    ),
        .o_icache_fetchInfo     (     ),

        .i_backend_branchwb_vld ( 0 ),
        .i_backend_branchwbInfo ( ),

        .i_commit_vld           ( 0         ),
        .i_commit_ftqIdx        (        )
    );



    FTQ u_FTQ(
        .clk                    ( clk                    ),
        .rst                    ( rst                    ),

        .i_squash_vld           ( i_squash_vld           ),
        .i_squashInfo           ( i_squashInfo           ),

        .i_pred_req             ( toFTQ_pred_vld             ),
        .o_ftq_rdy              ( toBPU_ftq_rdy              ),
        .i_pred_ftqInfo         ( toFTQ_pred_ftqInfo         ),

        .o_bpu_update           ( toBPU_update_vld           ),
        .i_bpu_update_finished  ( toFTQ_update_finished  ),
        .o_BPUupdateInfo        ( toBPU_updateInfo        ),

        .o_icache_fetch_req     (      ),
        .i_icache_fetch_rdy     (      ),
        .o_icache_fetchInfo     (      ),

        .i_read_ftqIdx          (           ),
        .o_read_ftqStartAddr    (     ),
        .o_read_ftqNextAddr     (      ),

        .i_backend_branchwb_vld (  ),
        .i_backend_branchwbInfo (  ),

        .i_commit_vld           (            ),
        .i_commit_ftqIdx        (         )
    );




/****************************************************************************************************/
// 3 stage icache
/****************************************************************************************************/










endmodule


