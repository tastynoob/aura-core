
`include "core_define.svh"



// decode -> rename -> rob

module ctrlBlock (
    input wire clk,
    input wire rst,

    // from/ fetch
    output wire o_stall,
    input wire [`WDEF(`FETCH_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`FETCH_WIDTH],

    output csr_in_pack_t o_csr_pack,
    csrrw_if.s if_csrrw,
    syscall_if.s if_syscall,

    // read immBuffer (clear when writeback)
    input irobIdx_t i_read_irob_idx[`IMMBUFFER_READPORT_NUM],
    output imm_t o_read_irob_data[`IMMBUFFER_READPORT_NUM],
    input wire [`WDEF(`IMMBUFFER_CLEARPORT_NUM)] i_clear_irob_vld,
    input irobIdx_t i_clear_irob_idx[`IMMBUFFER_CLEARPORT_NUM],

    // read ftqOffset (exu read from rob)
    input wire [
    `WDEF($clog2(`ROB_SIZE))
    ] i_read_ftqOffset_idx[`BRU_NUM + `LDU_NUM + `STU_NUM],
    output ftqOffset_t o_read_ftqOffset_data[`BRU_NUM + `LDU_NUM + `STU_NUM],

    // write back, from exu
    // common writeback
    input wire [`WDEF(`COMPLETE_NUM)] i_fu_finished,
    input comwbInfo_t i_comwbInfo[`COMPLETE_NUM],
    // branch writeback (branch taken or mispred)
    input wire i_branchwb_vld,
    input branchwbInfo_t i_branchwb_info,
    // except writeback
    input wire i_exceptwb_vld,
    input exceptwbInfo_t i_exceptwb_info,

    // to exe block
    // mark regfile status to not ready
    output wire [`WDEF(`RENAME_WIDTH)] o_disp_mark_notready_vld,
    output iprIdx_t o_disp_mark_notready_iprIdx[`RENAME_WIDTH],

    disp_if.m if_disp,

    // notify ftq and storeQue
    output wire o_commit_vld,
    output wire [`WDEF($clog2(`ROB_SIZE))] o_commit_rob_idx,
    output wire o_commit_ftq_vld,
    output ftqIdx_t o_commit_ftq_idx,

    // read ftq startAddress from ftq
    output wire o_read_ftq_Vld,
    output ftqIdx_t o_read_ftqIdx,
    input wire [`XDEF] i_read_ftqStartAddr,

    output wire [`WDEF($clog2(`COMMIT_WIDTH))] o_committed_stores,
    output wire [`WDEF($clog2(`COMMIT_WIDTH))] o_committed_loads,

    output wire o_squash_vld,
    output squashInfo_t o_squashInfo
);
    genvar i;

    /****************************************************************************************************/
    // fetch inst buffer
    //
    /****************************************************************************************************/
    fetchEntry_t toDecode_data[`DECODE_WIDTH];
    wire [`WDEF(`DECODE_WIDTH)] toDecode_inst_vld;
    wire [`WDEF(`DECODE_WIDTH)] toInstBuffer_deq_req;
    wire can_insert_instBuffer;

    fifo #(
        .dtype      (fetchEntry_t),
        .INPORT_NUM (`FETCH_WIDTH),
        .OUTPORT_NUM(`DECODE_WIDTH),
        .DEPTH      (32),
        .USE_INIT   (0)
    ) fetch_inst_buffer (
        .clk    (clk),
        .rst    (rst),
        .i_flush(o_squash_vld),

        .o_can_enq (can_insert_instBuffer),
        .i_enq_vld (can_insert_instBuffer),
        .i_enq_req (i_inst_vld),
        .i_enq_data(i_inst),

        .o_can_deq (toDecode_inst_vld),
        .i_deq_req (toInstBuffer_deq_req),
        .o_deq_data(toDecode_data)
    );

    assign o_stall = !can_insert_instBuffer;

    /****************************************************************************************************/
    // decode
    //
    /****************************************************************************************************/

    wire [`WDEF(`DECODE_WIDTH)] toRename_vld;
    decInfo_t toRename_decInfo[`DECODE_WIDTH];
    wire toDecode_stall;

    decode u_decode (
        .clk(clk),
        .rst(rst),

        .i_stall     (toDecode_stall),
        .i_squash_vld(o_squash_vld),

        .o_can_deq (toInstBuffer_deq_req),
        .i_inst_vld(toDecode_inst_vld),
        .i_inst    (toDecode_data),

        .o_decinfo_vld(toRename_vld),
        .o_decinfo    (toRename_decInfo)
    );




    /****************************************************************************************************/
    // rename
    //
    /****************************************************************************************************/
    wire [`WDEF(`MEMDEP_FOLDPC_WIDTH)] toMemDep_foldpc[`RENAME_WIDTH];
    generate
        for (i = 0; i < `RENAME_WIDTH; i = i + 1) begin
            assign toMemDep_foldpc[i] = toRename_decInfo[i].foldpc;
        end
    endgenerate


    wire toRename_stall;
    wire [`WDEF(`RENAME_WIDTH)] toDIspatch_vld;
    renameInfo_t toDIspatch_renameInfo[`RENAME_WIDTH];

    wire [`WDEF(`COMMIT_WIDTH)] toRename_commit;
    renameCommitInfo_t toRename_commitInfo[`COMMIT_WIDTH];

    rename u_rename (
        .rst(rst),
        .clk(clk),

        .o_stall(toDecode_stall),
        .i_stall(toRename_stall),

        .i_squash_vld(o_squash_vld),

        .i_commit_vld(toRename_commit),
        .i_commitInfo(toRename_commitInfo),

        .i_decinfo_vld(toRename_vld),
        .i_decinfo    (toRename_decInfo),

        .o_rename_vld(toDIspatch_vld),
        .o_renameInfo(toDIspatch_renameInfo)
    );

    /****************************************************************************************************/
    // memory dependcy predictor
    //
    /****************************************************************************************************/
    wire violation;
    wire [`WDEF(`RENAME_WIDTH)] toMemDep_insert_store;
    robIdx_t toMemDep_alloc_robIdx[`RENAME_WIDTH];
    assign violation = o_squash_vld && o_squashInfo.dueToViolation;

    wire [`WDEF(`RENAME_WIDTH)] mem_shouldWait;
    robIdx_t mem_dep_robIdx[`RENAME_WIDTH];

    generate
        for (i = 0; i < `RENAME_WIDTH; i = i + 1) begin
            assign toMemDep_insert_store[i] = toDIspatch_vld[i] && toDIspatch_renameInfo[i].isStore;
        end
    endgenerate

    memDepPred u_memDepPred (
        .clk               (clk),
        .rst               (rst),
        .i_stall           (toRename_stall),
        // s1
        .i_lookup_ssit_vld ((~0)),                   // dont care
        .i_foldpc          (toMemDep_foldpc),
        // s2
        .i_insert_store    (toMemDep_insert_store),
        .i_allocated_robIdx(toMemDep_alloc_robIdx),
        .o_shouldwait      (mem_shouldWait),
        .o_dep_robIdx      (mem_dep_robIdx),

        .i_store_issued(0),
        .i_issue_foldpc(),
        .i_store_robIdx(),

        .i_violation       (violation),
        .i_vio_store_foldpc(o_squashInfo.stpc),
        .i_vio_load_foldpc (o_squashInfo.ldpc),
        // dispQue -> issueQue
        .i_read_robIdx     (),
        .o_memdep_rdy      ()
    );


    /****************************************************************************************************/
    // dispatch and rob
    //
    /****************************************************************************************************/

    wire toDispatch_can_insert;
    wire toROB_insert_vld;
    wire [`WDEF(`RENAME_WIDTH)] toROB_insert_req, toROB_insert_ismv;
    ROBEntry_t toROB_new_entry[`RENAME_WIDTH];
    ftqOffset_t toROB_new_enrty_ftqOffset[`RENAME_WIDTH];
    robIdx_t toDispatch_alloc_robIdx[`RENAME_WIDTH];

    wire toROB_disp_exceptwb_vld;
    exceptwbInfo_t toROB_disp_exceptwb_info;

    assign toMemDep_alloc_robIdx = toDispatch_alloc_robIdx;

    wire toDisp_disp_serialize;
    wire toDisp_commit_serialize;

    dispatch u_dispatch (
        .clk                     (clk),
        .rst                     (rst || o_squash_vld),
        .i_squash_vld            (o_squash_vld),
        .i_can_dispatch_serialize(toDisp_disp_serialize),
        .i_commit_serialize      (toDisp_commit_serialize),

        .o_stall(toRename_stall),

        .i_enq_vld (toDIspatch_vld),
        .i_enq_inst(toDIspatch_renameInfo),

        .i_read_irob_idx (i_read_irob_idx),
        .o_read_irob_data(o_read_irob_data),
        .i_clear_irob_vld(i_clear_irob_vld),
        .i_clear_irob_idx(i_clear_irob_idx),

        .i_can_insert_rob        (toDispatch_can_insert),
        .o_insert_rob_vld        (toROB_insert_vld),
        .o_insert_rob_req        (toROB_insert_req),
        .o_insert_rob_ismv       (toROB_insert_ismv),
        .o_new_robEntry          (toROB_new_entry),
        .o_new_robEntry_ftqOffset(toROB_new_enrty_ftqOffset),
        .i_alloc_robIdx          (toDispatch_alloc_robIdx),

        .o_exceptwb_vld (toROB_disp_exceptwb_vld),
        .o_exceptwb_info(toROB_disp_exceptwb_info),

        .if_disp(if_disp)
    );

    generate
        for (i = 0; i < `RENAME_WIDTH; i = i + 1) begin
            assign o_disp_mark_notready_vld[i] = toDispatch_can_insert && toROB_insert_vld && toROB_insert_req[i] && (!toROB_insert_ismv[i]);
            assign o_disp_mark_notready_iprIdx[i] = toROB_new_entry[i].iprd_idx;
        end
    endgenerate

    csr_in_pack_t toROB_csr_pack;
    trap_pack_t toPriv_trap_pack;

    ROB u_ROB (
        .clk(clk),
        .rst(rst),

        .i_csr_pack (toROB_csr_pack),
        .o_trap_pack(toPriv_trap_pack),
        .if_syscall (if_syscall),

        .o_can_enq(toDispatch_can_insert),
        .i_enq_vld(toROB_insert_vld),
        .i_enq_req(toROB_insert_req),

        .i_insert_rob_ismv    (toROB_insert_ismv),
        .i_new_entry          (toROB_new_entry),
        .i_new_entry_ftqOffset(toROB_new_enrty_ftqOffset),
        .o_alloc_robIdx       (toDispatch_alloc_robIdx),

        .i_read_ftqOffset_idx (i_read_ftqOffset_idx),
        .o_read_ftqOffset_data(o_read_ftqOffset_data),

        .i_fu_finished(i_fu_finished),
        .i_comwbInfo(i_comwbInfo),
        .i_branchwb_vld(i_branchwb_vld),
        .i_branchwb_info(i_branchwb_info),
        .i_exceptwb_vld(i_exceptwb_vld || toROB_disp_exceptwb_vld),
        .i_exceptwb_info(i_exceptwb_vld ? i_exceptwb_info : toROB_disp_exceptwb_info),

        .o_commit_vld    (o_commit_vld),
        .o_commit_rob_idx(o_commit_rob_idx),
        .o_commit_ftq_vld(o_commit_ftq_vld),
        .o_commit_ftq_idx(o_commit_ftq_idx),

        .o_rename_commit    (toRename_commit),
        .o_rename_commitInfo(toRename_commitInfo),

        .o_read_ftq_Vld     (o_read_ftq_Vld),
        .o_read_ftqIdx      (o_read_ftqIdx),
        .i_read_ftqStartAddr(i_read_ftqStartAddr),

        .o_committed_stores      (o_committed_stores),
        .o_committed_loads       (o_committed_loads),
        .o_can_dispatch_serialize(toDisp_disp_serialize),
        .o_commit_serialized_inst(toDisp_commit_serialize),
        .o_squash_vld            (o_squash_vld),
        .o_squashInfo            (o_squashInfo)
    );



    priv_ctrl u_priv_ctrl (
        .clk           (clk),
        .rst           (rst),
        .o_priv_sysInfo(toROB_csr_pack),
        .i_trap_handle (toPriv_trap_pack),
        .if_syscall    (if_syscall),

        .i_access      (if_csrrw.access),
        .i_read_csrIdx (if_csrrw.read_idx),
        .o_read_illegal(if_csrrw.illegal),
        .o_read_val    (if_csrrw.read_val),
        .i_write       (if_csrrw.write),
        .i_write_csrIdx(if_csrrw.write_idx),
        .i_write_val   (if_csrrw.write_val)
    );

    assign o_csr_pack = toROB_csr_pack;



endmodule
