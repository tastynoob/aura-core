`include "backend_define.svh"




module aura_backend (
    input wire clk,
    input wire rst,

    output wire o_squash_vld,
    output squashInfo_t o_squashInfo,

    // branch writeback to ftq
    output wire [`WDEF(`BRU_NUM)] o_branchwb_vld,
    output branchwbInfo_t o_branchwbInfo[`BRU_NUM],

    // read ftq startAddress from ftq
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM + `LDU_NUM + `STU_NUM],
    input wire [`XDEF] i_read_ftqStartAddr[`BRU_NUM + `LDU_NUM + `STU_NUM],
    input wire [`XDEF] i_read_ftqNextAddr[`BRU_NUM + `LDU_NUM + `STU_NUM],

    // from fetch
    output wire o_stall,
    input wire [`WDEF(`FETCH_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`FETCH_WIDTH],

    output wire o_commit_ftq_vld,
    output ftqIdx_t o_commit_ftqIdx
);
    genvar i;

    wire squash_vld;
    squashInfo_t squashInfo;

    irobIdx_t toCtrl_read_irob_idx[`IMMBUFFER_READPORT_NUM];
    imm_t toExe_read_irob_data[`IMMBUFFER_READPORT_NUM];
    wire [`WDEF(`IMMBUFFER_CLEARPORT_NUM)] toCtrl_clear_irob_vld;
    irobIdx_t toCtrl_clear_irob_idx[`IMMBUFFER_CLEARPORT_NUM];

    wire [
    `WDEF($clog2(`ROB_SIZE))
    ] toCtrl_read_rob_idx[`BRU_NUM + `LDU_NUM + `STU_NUM];
    ftqOffset_t toExe_read_rob_ftqOffset[`BRU_NUM + `LDU_NUM + `STU_NUM];

    wire [`WDEF(`RENAME_WIDTH)] toExe_mark_notready_vld;
    iprIdx_t toExe_mark_notready_iprIdx[`RENAME_WIDTH];

    wire rob_read_ftq_vld;
    ftqIdx_t rob_read_ftqIdx;
    wire [`XDEF] rob_read_ftqStartAddr = i_read_ftqStartAddr[0];

    wire [`WDEF(`COMPLETE_NUM)] toCtrl_fu_finished;
    comwbInfo_t toCtrl_comwbInfo[`COMPLETE_NUM];

    wire [`WDEF(`BRU_NUM)] exeBlock_branchwb_mispred_vld;
    wire [`WDEF(`BRU_NUM)] exeBlock_branchwb_vld;
    branchwbInfo_t exeBlock_branchwbInfo[`BRU_NUM];
    // to ftq
    wire [`WDEF(`BRU_NUM)] toFTQ_branchwb_vld;
    branchwbInfo_t toFTQ_branchwbInfo[`BRU_NUM];
    assign toFTQ_branchwbInfo = exeBlock_branchwbInfo;
    // to rob
    wire toCtrl_branchwb_vld;
    assign toCtrl_branchwb_vld = |exeBlock_branchwb_mispred_vld;
    branchwbInfo_t toCtrl_branchwbInfo;

    wire toCtrl_except_vld;
    exceptwbInfo_t toCtrl_exceptwbInfo;

    wire commit_vld;
    robIdx_t commit_robIdx;

    csr_in_pack_t toExec_csr_pack;
    csrrw_if toCtrl_csrrw ();
    syscall_if toCtrl_syscall ();

    disp_if toExe_disp ();

    wire [`SDEF(`COMMIT_WIDTH)] toExe_committed_stores;
    wire [`SDEF(`COMMIT_WIDTH)] toExe_committed_loads;

    ctrlBlock u_ctrlBlock (
        .clk(clk),
        .rst(rst),

        .o_stall   (o_stall),
        .i_inst_vld(i_inst_vld),
        .i_inst    (i_inst),

        .o_csr_pack(toExec_csr_pack),
        .if_csrrw  (toCtrl_csrrw),
        .if_syscall(toCtrl_syscall),

        .i_read_irob_idx (toCtrl_read_irob_idx),
        .o_read_irob_data(toExe_read_irob_data),
        .i_clear_irob_vld(toCtrl_clear_irob_vld),
        .i_clear_irob_idx(toCtrl_clear_irob_idx),

        .i_read_ftqOffset_idx(toCtrl_read_rob_idx),  // TODO: BRU need ftqOffset
        .o_read_ftqOffset_data(toExe_read_rob_ftqOffset),

        .i_fu_finished  (toCtrl_fu_finished),
        .i_comwbInfo    (toCtrl_comwbInfo),
        .i_branchwb_vld (toCtrl_branchwb_vld),
        .i_branchwb_info(toCtrl_branchwbInfo),
        .i_exceptwb_vld (toCtrl_except_vld),
        .i_exceptwb_info(toCtrl_exceptwbInfo),

        .o_disp_mark_notready_vld   (toExe_mark_notready_vld),
        .o_disp_mark_notready_iprIdx(toExe_mark_notready_iprIdx),

        .if_disp(toExe_disp),

        .o_commit_vld    (commit_vld),
        .o_commit_rob_idx(commit_robIdx),
        .o_commit_ftq_vld(o_commit_ftq_vld),
        .o_commit_ftq_idx(o_commit_ftqIdx),

        .o_read_ftq_Vld     (rob_read_ftq_vld),
        .o_read_ftqIdx      (rob_read_ftqIdx),
        .i_read_ftqStartAddr(rob_read_ftqStartAddr),

        .o_committed_stores(toExe_committed_stores),
        .o_committed_loads (toExe_committed_loads),

        .o_squash_vld(squash_vld),
        .o_squashInfo(squashInfo)
    );


    assign o_branchwb_vld = toFTQ_branchwb_vld;
    assign o_branchwbInfo = toFTQ_branchwbInfo;
    assign o_squash_vld = squash_vld;
    assign o_squashInfo = squashInfo;


    ftqIdx_t exeBlock_read_ftqIdx[`BRU_NUM + `LDU_NUM + `STU_NUM];
    exeBlock u_exeBlock (
        .clk         (clk),
        .rst         (rst),
        .i_squash_vld(squash_vld),
        .i_squashInfo(squashInfo),

        .i_disp_mark_notready_vld   (toExe_mark_notready_vld),
        .i_disp_mark_notready_iprIdx(toExe_mark_notready_iprIdx),

        .if_disp(toExe_disp),

        .o_read_irob_idx (toCtrl_read_irob_idx),
        .i_read_irob_data(toExe_read_irob_data),
        .o_immB_clear_vld(toCtrl_clear_irob_vld),
        .o_immB_clear_idx(toCtrl_clear_irob_idx),

        .o_read_ftqIdx      (exeBlock_read_ftqIdx),
        .i_read_ftqStartAddr(i_read_ftqStartAddr),
        .i_read_ftqNextAddr (i_read_ftqNextAddr),
        .o_read_robIdx      (toCtrl_read_rob_idx),
        .i_read_ftqOffset   (toExe_read_rob_ftqOffset),

        .i_csr_pack(toExec_csr_pack),
        .if_csrrw  (toCtrl_csrrw),
        .if_syscall(toCtrl_syscall),

        .o_fu_finished  (toCtrl_fu_finished),
        .o_comwbInfo    (toCtrl_comwbInfo),
        .o_branchwb_vld (exeBlock_branchwb_vld),
        .o_branchwb_info(exeBlock_branchwbInfo),

        .i_committed_stores(toExe_committed_stores),
        .i_committed_loads (toExe_committed_loads),

        .o_exceptwb_vld (toCtrl_except_vld),
        .o_exceptwb_info(toCtrl_exceptwbInfo)
    );

    always_comb begin
        // rob read ftq use exeblock's port
        o_read_ftqIdx = exeBlock_read_ftqIdx;
        if (rob_read_ftq_vld) begin
            o_read_ftqIdx[0] = rob_read_ftqIdx;
        end
    end


    generate
        for (i = 0; i < `BRU_NUM; i = i + 1) begin
            assign exeBlock_branchwb_mispred_vld[i] = (exeBlock_branchwb_vld[i] && exeBlock_branchwbInfo[i].has_mispred);
        end
    endgenerate

    wire write_the_same_ftqEntry = (&exeBlock_branchwb_vld) && (exeBlock_branchwbInfo[0].ftq_idx == exeBlock_branchwbInfo[1].ftq_idx);
    robIdx_t brwb_robIdx0, brwb_robIdx1;
    assign brwb_robIdx0 = exeBlock_branchwbInfo[0].rob_idx;
    assign brwb_robIdx1 = exeBlock_branchwbInfo[1].rob_idx;

    wire age_0_larger_1 = `OLDER_THAN(brwb_robIdx0, brwb_robIdx1);

    assign toFTQ_branchwb_vld = write_the_same_ftqEntry ? (age_0_larger_1 ? 2'b01 : 2'b10) : exeBlock_branchwb_vld;

    oldest_select #(
        .WIDTH(`BRU_NUM),
        .dtype(branchwbInfo_t)
    ) u_oldest_select (
        .i_vld(exeBlock_branchwb_mispred_vld),
        .i_rob_idx({
            exeBlock_branchwbInfo[0].rob_idx, exeBlock_branchwbInfo[1].rob_idx
        }),
        .i_datas(exeBlock_branchwbInfo),
        .o_oldest_data(toCtrl_branchwbInfo)
    );

endmodule


