`include "core_define.svh"
`include "funcs.svh"

//if one inst is mv
//should not dispatch to
//mark mv complete

import "DPI-C" function void dispatch_stall(uint64_t reason);

// order in
module dispatch (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input wire i_can_dispatch_serialize,
    input wire i_commit_serialize,

    // to rename
    output wire o_stall,

    // from rename
    input wire [`WDEF(`RENAME_WIDTH)] i_enq_vld,
    input renameInfo_t i_enq_inst[`RENAME_WIDTH],
    // from mem dep predictor
    input wire [`WDEF(`RENAME_WIDTH)] i_mem_shouldwait,
    input robIdx_t i_mem_dep_robIdx[`RENAME_WIDTH],

    // read immBuffer (clear when writeback)
    input irobIdx_t i_read_irob_idx[`IMMBUFFER_READPORT_NUM],
    output imm_t o_read_irob_data[`IMMBUFFER_READPORT_NUM],
    input wire [`WDEF(`IMMBUFFER_CLEARPORT_NUM)] i_clear_irob_vld,
    input irobIdx_t i_clear_irob_idx[`IMMBUFFER_CLEARPORT_NUM],

    // from/to rob
    input wire i_can_insert_rob,
    output wire o_insert_rob_vld,
    output wire [`WDEF(`RENAME_WIDTH)] o_insert_rob_req,
    output wire [`WDEF(`RENAME_WIDTH)] o_insert_rob_ismv,  //if ismv, mark mv is finished
    output ROBEntry_t o_new_robEntry[`RENAME_WIDTH],
    output ftqOffset_t o_new_robEntry_ftqOffset[`RENAME_WIDTH],
    input robIdx_t i_alloc_robIdx[`RENAME_WIDTH],
    // if frontend or decode has except
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    disp_if.m if_disp
);
    genvar i;

    //alloc immBubbfer id
    wire [`WDEF(`RENAME_WIDTH)] use_imm_vec;
    irobIdx_t irob_alloc_idx[`RENAME_WIDTH];  // alloced immBuffer id
    imm_t imm_vec[`RENAME_WIDTH];

    wire can_insert_intDQ;
    wire can_insert_memDQ;
    wire can_insert_immBuffer;
    // only when can_dispatch is true
    wire can_dispatch = i_can_insert_rob && can_insert_intDQ && can_insert_memDQ && can_insert_immBuffer;

    logic [`WDEF(`RENAME_WIDTH)] insert_rob_vld;
    logic [`WDEF(`RENAME_WIDTH)] insert_intDQ_vld;
    logic [`WDEF(`RENAME_WIDTH)] insert_memDQ_vld;
    microOp_t new_intDQEntry[`RENAME_WIDTH];
    microOp_t new_memDQEntry[`RENAME_WIDTH];

    robIdx_t oldest_except_robIdx;
    rv_trap_t::exception oldest_except;

    // new rob entry
    assign insert_rob_vld = i_enq_vld;
    generate
        for (i = 0; i < `RENAME_WIDTH; i = i + 1) begin
            assign o_insert_rob_ismv[i] = i_enq_inst[i].ismv || (i_enq_inst[i].dispQue_id == `UNKOWNBLOCK_ID);
            // new intDQ entry, skip mv
            assign insert_intDQ_vld[i] = i_enq_vld[i] && (i_enq_inst[i].dispQue_id == `INTBLOCK_ID) && (!i_enq_inst[i].ismv);
            // new memDQ entry
            assign insert_memDQ_vld[i] = i_enq_vld[i] && (i_enq_inst[i].dispQue_id == `MEMBLOCK_ID);

            assign use_imm_vec[i] = i_enq_vld[i] && i_enq_inst[i].use_imm && (!i_enq_inst[i].ismv);
            assign imm_vec[i] = i_enq_inst[i].imm20;
            assign o_new_robEntry[i] = '{
                    ftq_idx         : i_enq_inst[i].ftq_idx,
                    isRVC           : i_enq_inst[i].isRVC,
                    isLoad          : (i_enq_inst[i].issueQue_id == `LDUIQ_ID),
                    isStore         : i_enq_inst[i].isStore,
                    ismv            : i_enq_inst[i].ismv,
                    has_rd          : i_enq_inst[i].rd_wen,
                    ilrd_idx        : i_enq_inst[i].ilrd_idx,
                    iprd_idx        : i_enq_inst[i].iprd_idx,
                    prev_iprd_idx   : i_enq_inst[i].prev_iprd_idx,
                    serialized      : i_enq_inst[i].need_serialize,

                    instmeta        : i_enq_inst[i].instmeta
                };
            assign o_new_robEntry_ftqOffset[i] = i_enq_inst[i].ftqOffset;
            assign new_intDQEntry[i] = '{
                    default: 0,
                    ftqIdx      : i_enq_inst[i].ftq_idx,
                    robIdx      : i_alloc_robIdx[i],
                    irobIdx     : irob_alloc_idx[i],
                    rdwen       : i_enq_inst[i].rd_wen,
                    iprd        : i_enq_inst[i].iprd_idx,
                    iprs        : i_enq_inst[i].iprs_idx,
                    useImm      : i_enq_inst[i].use_imm,
                    issueQueId  : i_enq_inst[i].issueQue_id,
                    micOp       : i_enq_inst[i].micOp_type,

                    seqNum      : i_enq_inst[i].instmeta
                };
            assign new_memDQEntry[i] = '{
                    default: 0,
                    ftqIdx      : i_enq_inst[i].ftq_idx,
                    robIdx      : i_alloc_robIdx[i],
                    irobIdx     : irob_alloc_idx[i],
                    rdwen       : i_enq_inst[i].rd_wen,
                    iprd        : i_enq_inst[i].iprd_idx,
                    iprs        : i_enq_inst[i].iprs_idx,
                    useImm      : i_enq_inst[i].use_imm,
                    issueQueId  : i_enq_inst[i].issueQue_id,
                    micOp       : i_enq_inst[i].micOp_type,
                    shouldwait  : i_mem_shouldwait[i],
                    depIdx      : i_mem_dep_robIdx[i],

                    seqNum      : i_enq_inst[i].instmeta
                };
        end
    endgenerate
    always_comb begin
        int ca;
        oldest_except_robIdx = i_alloc_robIdx[`RENAME_WIDTH-1];
        oldest_except = i_enq_inst[`RENAME_WIDTH-1].except;
        for (ca = `RENAME_WIDTH - 1; ca >= 0; ca = ca - 1) begin
            if (i_enq_vld[ca] && i_enq_inst[ca].has_except) begin
                oldest_except = i_enq_inst[ca].except;
                oldest_except_robIdx = i_alloc_robIdx[ca];
            end
        end
    end
    assign o_insert_rob_vld = can_dispatch;
    assign o_insert_rob_req = insert_rob_vld;
    assign o_stall = i_enq_vld[0] ? (!can_dispatch) : 0;

    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
        end
        else begin
            if (o_stall) begin
                dispatch_stall((!i_can_insert_rob) ? 0 : (!can_insert_immBuffer) ? 1 : (!can_insert_intDQ) ? 2 : 3);
            end
            if (can_dispatch) begin
                for (fa = 0; fa < `RENAME_WIDTH; fa = fa + 1) begin
                    if (insert_intDQ_vld[fa] || insert_memDQ_vld[fa]) begin
                        update_instPos(i_enq_inst[fa].instmeta, difftest_def::AT_dispQue);
                    end
                end
            end
        end
    end


    /****************************************************************************************************/
    // frontend exception process ( instIllegal/pcMisaligned )
    // delay it by one cycle
    /****************************************************************************************************/

    logic [`WDEF(`RENAME_WIDTH)] has_except;
    exceptwbInfo_t oldest_except_info;
    always_comb begin
        int fa;
        for (fa = `RENAME_WIDTH - 1; fa >= 0; fa = fa - 1) begin
            has_except[fa] = insert_rob_vld[fa] && i_enq_inst[fa].has_except && can_dispatch;
        end
        oldest_except_info = '{default: 0, rob_idx : oldest_except_robIdx, except_type: oldest_except};
    end

    assign o_exceptwb_vld = (|has_except);
    assign o_exceptwb_info = oldest_except_info;

    `ORDER_CHECK(insert_rob_vld);


    /****************************************************************************************************/
    // int dispQue
    /****************************************************************************************************/

    wire [`WDEF(`INTDQ_DISP_WID)] intDQ_disp_vec;
    dispQue #(
        .DEPTH      (`INTDQ_SIZE),
        .INPORT_NUM (`RENAME_WIDTH),
        .OUTPORT_NUM(`INTDQ_DISP_WID),
        .dtype      (microOp_t)
    ) u_int_dispQue (
        .clk    (clk),
        .rst    (rst),
        .i_flush(i_squash_vld),

        .o_can_enq (can_insert_intDQ),
        .i_enq_vld (can_dispatch),
        .i_enq_req (insert_intDQ_vld),
        .i_enq_data(new_intDQEntry),

        .o_can_deq (intDQ_disp_vec),
        .i_deq_req (if_disp.int_rdy),
        .o_deq_data(if_disp.int_info)
    );

    /* verilator lint_off UNOPTFLAT */
    wire [`WDEF(`INTDQ_DISP_WID)] serialize_front;
    wire [`WDEF(`INTDQ_DISP_WID)] need_serialize;

    generate
        for (i = 0; i < `INTDQ_DISP_WID; i = i + 1) begin
            assign need_serialize[i] = intDQ_disp_vec[i] & (if_disp.int_info[i].issueQueId == `SCUIQ_ID);
            if (i == 0) begin
                assign serialize_front[i] = intDQ_disp_vec[i] & (if_disp.int_info[i].issueQueId != `SCUIQ_ID);
            end
            else begin
                assign serialize_front[i] =
                        intDQ_disp_vec[i] & serialize_front[i-1] & (if_disp.int_info[i].issueQueId != `SCUIQ_ID);
            end
        end
    endgenerate

    reg [`WDEF(2)] status;

    always_ff @(posedge clk) begin
        if (rst || i_squash_vld) begin
            status <= 0;
        end
        else begin
            if (status == 0 && (|need_serialize)) begin
                status <= 1;  // disp inst in front
            end
            else if (status == 1 && i_can_dispatch_serialize) begin
                status <= 2;  // disp serialied inst
            end
            else if (status == 2) begin
                assert (if_disp.int_rdy == 1);
                status <= 3;  // finish disp serialied inst
            end
            else if (status == 3 && i_commit_serialize) begin
                status <= 0;
            end
        end
    end


    assign if_disp.int_req = status == 0 ? serialize_front : status == 1 ? 0 : status == 2 ? 1 : status == 3 ? 0 : 0;
    /****************************************************************************************************/
    // mem dispQue
    /****************************************************************************************************/


    dispQue #(
        .DEPTH      (`MEMDQ_SIZE),
        .INPORT_NUM (`RENAME_WIDTH),
        .OUTPORT_NUM(`INTDQ_DISP_WID),
        .dtype      (microOp_t)
    ) u_mem_dispQue (
        .clk    (clk),
        .rst    (rst),
        .i_flush(i_squash_vld),

        .o_can_enq (can_insert_memDQ),
        .i_enq_vld (can_dispatch),
        .i_enq_req (insert_memDQ_vld),
        .i_enq_data(new_memDQEntry),

        .o_can_deq (if_disp.mem_req),
        .i_deq_req (if_disp.mem_rdy),
        .o_deq_data(if_disp.mem_info)
    );


    /****************************************************************************************************/
    // imm reorder buffer
    /****************************************************************************************************/
    //DESIGN:
    //when this inst is completed (writeback finished)
    //this entry can be freed
    dataQue #(
        .DEPTH        (`IMMBUFFER_SIZE),
        .INPORT_NUM   (`RENAME_WIDTH),
        .READPORT_NUM (`IMMBUFFER_READPORT_NUM),
        .CLEARPORT_NUM(`IMMBUFFER_CLEARPORT_NUM),
        .COMMIT_WID   (`IMMBUFFER_COMMIT_WID),
        .dtype        (imm_t)
    ) u_immBuffer (
        .clk(clk),
        .rst(rst || i_squash_vld),

        .o_can_enq (can_insert_immBuffer),
        .i_enq_vld (can_dispatch),
        .i_enq_req (use_imm_vec),
        .i_enq_data(imm_vec),
        .o_alloc_id(irob_alloc_idx),

        .i_read_dqIdx(i_read_irob_idx),
        .o_read_data (o_read_irob_data),

        .i_clear_vld  (i_clear_irob_vld),
        .i_clear_dqIdx(i_clear_irob_idx)
    );

endmodule








