`include "backend_define.svh"




module aura_backend (
    input wire clk,
    input wire rst,

    output wire o_squash_vld,
    output squashInfo_t o_squashInfo,

    // branch writeback
    output wire[`WDEF(`BRU_NUM)] o_branchwb_vld,
    output branchwbInfo_t o_branchwbInfo[`BRU_NUM],

    output irobIdx_t o_read_irob_idx[`ALU_NUM],
    input wire[`IMMDEF] i_read_irob_data[`ALU_NUM],

    // read ftq startAddress from ftq
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    input wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],
    input wire [`XDEF] i_read_ftqNextAddr[`BRU_NUM],

    // from fetch
    output wire o_stall,
    input wire[`WDEF(`FETCH_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`FETCH_WIDTH],

    output wire o_commit_vld,
    output ftqIdx_t o_commit_ftqIdx
);

    wire squash_vld;
    squashInfo_t squashInfo;

    irobIdx_t toCtrl_read_irob_idx[`IMMBUFFER_READPORT_NUM];
    imm_t toCtrl_read_irob_data[`IMMBUFFER_READPORT_NUM];

    wire[`WDEF(`RENAME_WIDTH)] toExe_mark_notready_vld;
    iprIdx_t toExe_mark_notready_iprIdx[`RENAME_WIDTH];

    wire toCtrl_intDQ_deq_vld;
    wire[`WDEF(`INTDQ_DISP_WID)] toExe_intDQ_deq_req;
    intDQEntry_t toExe_intDQ_deq_info[`INTDQ_DISP_WID];


    wire rob_read_ftq_vld;
    ftqIdx_t rob_read_ftqIdx;
    wire[`XDEF] rob_read_ftqStartAddr = i_read_ftqStartAddr[0];

    ctrlBlock u_ctrlBlock(
        .clk                   ( clk                   ),
        .rst                   ( rst                   ),

        .o_stall               ( o_stall               ),
        .i_inst_vld            ( i_inst_vld            ),
        .i_inst                ( i_inst                ),

        .i_read_irob_idx       (      ),
        .i_read_irob_data      (       ),
        .i_clear_irob_vld      ( 0      ),
        .i_clear_irob_idx      (     ),

        .i_read_ftqOffset_idx  (   ),
        .o_read_ftqOffset_data (  ),

        .i_wb_vld              ( 0        ),
        .i_valwb_info          (          ),
        .i_branchwb_vld        ( 0        ),
        .i_branchwb_info       (          ),
        .i_exceptwb_vld        ( 0        ),
        .i_exceptwb_info       (          ),

        .o_disp_mark_notready_vld    ( toExe_mark_notready_vld ),
        .o_disp_mark_notready_iprIdx ( toExe_mark_notready_iprIdx ),

        .i_intDQ_deq_vld       ( toCtrl_intDQ_deq_vld      ),
        .o_intDQ_deq_req       ( toExe_intDQ_deq_req       ),
        .o_intDQ_deq_info      ( toExe_intDQ_deq_info      ),

        .o_commit_vld          (           ),
        .o_commit_rob_idx      (       ),
        .o_commit_ftq_idx      (       ),

        .o_read_ftq_Vld        ( rob_read_ftq_vld      ),
        .o_read_ftqIdx         ( rob_read_ftqIdx       ),
        .i_read_ftqStartAddr   ( rob_read_ftqStartAddr ),

        .o_squash_vld          ( squash_vld          ),
        .o_squashInfo          ( squashInfo          )
    );


    assign o_branchwb_vld = 0;
    assign o_commit_vld = 0;
    assign o_squash_vld = 0;// squash_vld;
    // assign o_squashInfo = squashInfo;


    ftqIdx_t exeBlock_read_ftqIdx[`BRU_NUM];
    exeBlock u_exeBlock(
        .clk                         ( clk  ),
        .rst                         ( rst  ),

        .i_disp_mark_notready_vld    ( toExe_mark_notready_vld    ),
        .i_disp_mark_notready_iprIdx ( toExe_mark_notready_iprIdx ),

        .o_intDQ_deq_vld     ( toCtrl_intDQ_deq_vld ),
        .i_intDQ_deq_req     ( toExe_intDQ_deq_req  ),
        .i_intDQ_deq_info    ( toExe_intDQ_deq_info ),

        .o_read_irob_idx     ( o_read_irob_idx ),
        .i_read_irob_data    ( i_read_irob_data ),

        .o_read_ftqIdx       ( exeBlock_read_ftqIdx ),
        .i_read_ftqStartAddr ( i_read_ftqStartAddr  ),
        .i_read_ftqNextAddr  ( i_read_ftqNextAddr   ),

        .o_wb_vld            (               ),
        .o_wbInfo            (               ),
        .o_branchwb_vld      (               ),
        .o_branchwb_info     (               ),
        .o_exceptwb_vld      (               ),
        .o_exceptwb_info     (               )
    );

    always_comb begin
        // rob read ftq use exeblock's port
        o_read_ftqIdx = exeBlock_read_ftqIdx;
        if (rob_read_ftq_vld) begin
            o_read_ftqIdx[0] = rob_read_ftqIdx;
        end
    end










endmodule


