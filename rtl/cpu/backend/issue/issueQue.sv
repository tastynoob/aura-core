`include "core_define.svh"


// Issue Stage:
// select(i0), readRegfile(i1), bypassData(i2)

// cancel cause:
// fu stall
// load replay
// replay may come from i1, i2

// free IQEntry at i2 if no cancelEvent

// sigle cycle instruct select:
// | woken+select | wakeOthers/read regfile | bypass |

// NOTE: wake from alu/mdu is absolutely correct
// wake from ldu is speculative

`define BUILD_ISSUESTATE(_micOp, _srcLpv, _iqIdx) \
    '{ \
        default : 0,                    \
        ftqIdx  : ``_micOp``.ftqIdx,     \
        robIdx  : ``_micOp``.robIdx,     \
        irobIdx : ``_micOp``.irobIdx,    \
        rdwen   : ``_micOp``.rdwen,      \
        iprd    : ``_micOp``.iprd,       \
        iprs    : ``_micOp``.iprs,       \
        useImm  : ``_micOp``.useImm,     \
        issueQueId : ``_micOp``.issueQueId,  \
        micOp   : ``_micOp``.micOp,      \
        iqIdx   : ``_iqIdx``,            \
        seqNum  : ``_micOp``.seqNum      \
    }

//unordered in,unordered out
module issueQue #(
    parameter int DEPTH              = 8,
    parameter int INOUTPORT_NUM      = 2,
    parameter int EXTERNAL_WAKEUPNUM = 2
) (
    input wire clk,
    input wire rst,

    //enq
    output wire o_can_enq,
    input wire [`WDEF(INOUTPORT_NUM)] i_enq_req,
    input microOp_t i_microOp[INOUTPORT_NUM],
    input wire [`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INOUTPORT_NUM],

    //output INOUTPORT_NUM entrys with the highest priority which is ready
    input wire [`WDEF(INOUTPORT_NUM)] i_fu_busy,
    output wire [`WDEF(INOUTPORT_NUM)] o_can_issue,  //find can issued entry
    output issueState_t o_issueState[INOUTPORT_NUM],

    input wire [`WDEF(INOUTPORT_NUM)] i_issueSuccess,
    input wire [`WDEF(INOUTPORT_NUM)] i_issueReplay,
    input wire [`WDEF($clog2(DEPTH))] i_feedbackIdx[INOUTPORT_NUM],

    loadwake_if.s if_loadwake,
    input wire [`WDEF(EXTERNAL_WAKEUPNUM)] i_ext_wk_vec,
    input iprIdx_t i_ext_wk_iprd[EXTERNAL_WAKEUPNUM],
    input lpv_t i_ext_wk_lpv[EXTERNAL_WAKEUPNUM][`NUMSRCS_INT]
);

    typedef struct {
        logic vld;  //unused in compressed RS
        logic issued;  // flag issued
        logic [`WDEF(`NUMSRCS_INT)] srcRdy;  // update by writeback

        microOp_t info;
    } IQEntry;

    genvar i, j;

    IQEntry buffer[DEPTH];
    logic [`WDEF(`NUMSRCS_INT)] nxtSrcRdy[DEPTH];

    //find the entry idx of buffer which can issue
    logic [`WDEF(INOUTPORT_NUM)] enq_find_free, deqRdy;  //is find the entry which is ready to issue
    logic [`WDEF($clog2(DEPTH))] enq_idx[INOUTPORT_NUM], deqIdx[INOUTPORT_NUM];  //the entrys that ready to issue
    reg [`WDEF(INOUTPORT_NUM)] s1_deqRdy;  //T0 compute and T1 use

    assign o_can_issue = s1_deqRdy;
    assign o_can_enq = &enq_find_free;

    wire [`WDEF(INOUTPORT_NUM)] real_enq_req = enq_find_free & i_enq_req;

    wire [`WDEF(DEPTH)] entry_ready;

    generate
        for (i = 0; i < DEPTH; i = i + 1) begin
            assign entry_ready[i] = buffer[i].vld && (!buffer[i].issued) && (&(nxtSrcRdy[i]));
        end
    endgenerate

    // enq find free
    always_comb begin
        int ca, cb;
        free_entry_selected[0] = 0;
        for (ca = 0; ca < INOUTPORT_NUM; ca = ca + 1) begin
            enq_idx[ca] = 0;
            enq_find_free[ca] = 0;

            if (ca == 0) begin
                for (cb = DEPTH - 1; cb >= 0; cb = cb - 1) begin
                    // find free entry
                    if (!buffer[cb].vld) begin
                        enq_idx[ca] = cb;
                        enq_find_free[ca] = 1;
                    end
                end
                free_entry_selected[ca][enq_idx[ca]] = enq_find_free[ca];
            end
            else begin
                free_entry_selected[ca] = free_entry_selected[ca-1];
                for (cb = DEPTH - 1; cb >= 0; cb = cb - 1) begin
                    //select free entry
                    if ((free_entry_selected[ca-1][cb] == 0) && (!buffer[cb].vld)) begin
                        enq_idx[ca] = cb;
                        enq_find_free[ca] = 1;
                    end
                end
                free_entry_selected[ca][enq_idx[ca]] = enq_find_free[ca];
            end
        end
    end

    // update status
    always_ff @(posedge clk) begin
        int fa, fb, fc;
        if (rst) begin
            s1_deqRdy <= 0;
            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                buffer[fa].vld <= 0;
            end
        end
        else begin
            for (fa = 0; fa < INOUTPORT_NUM; fa = fa + 1) begin
                // enq
                if (real_enq_req[fa]) begin
                    assert (buffer[enq_idx[fa]].vld == 0);
                    buffer[enq_idx[fa]].vld <= 1;
                    buffer[enq_idx[fa]].info <= i_microOp[fa];
                    buffer[enq_idx[fa]].issued <= 0;
                    buffer[enq_idx[fa]].srcRdy <= i_enq_iprs_rdy[fa];

                    update_instPos(i_microOp[fa].seqNum, difftest_def::AT_issueQue);
                end

                // deq/replay at i2
                if (i_issueSuccess[fa]) begin
                    assert (buffer[i_feedbackIdx[fa]].vld);
                    buffer[i_feedbackIdx[fa]].vld <= 0;
                end
                else if (i_issueReplay[fa]) begin
                    assert (buffer[i_feedbackIdx[fa]].vld);
                    buffer[i_feedbackIdx[fa]].issued <= 0;
                end
            end

            // schedule and issue
            if (|deqRdy) begin
                if (i_fu_busy == 2'b00) begin
                    // ports are free
                    s1_deqRdy <= deqRdy;
                    o_issueState[0] <= `BUILD_ISSUESTATE(buffer[deqIdx[0]].info, 0, deqIdx[0]);
                    o_issueState[1] <= `BUILD_ISSUESTATE(buffer[deqIdx[1]].info, 0, deqIdx[1]);
                    if (deqRdy[0]) begin
                        buffer[deqIdx[0]].issued <= 1;
                    end
                    if (deqRdy[1]) begin
                        buffer[deqIdx[1]].issued <= 1;
                    end
                end
                else if (i_fu_busy == 2'b01) begin
                    // port 0 is busy
                    s1_deqRdy <= {deqRdy[0], 1'b0};
                    o_issueState[1] <= `BUILD_ISSUESTATE(buffer[deqIdx[0]].info, 0, deqIdx[0]);
                    if (deqRdy[0]) begin
                        buffer[deqIdx[0]].issued <= 1;
                    end
                end
                else if (i_fu_busy == 2'b10) begin
                    // port 1 is busy
                    s1_deqRdy <= {1'b0, deqRdy[0]};
                    o_issueState[0] <= `BUILD_ISSUESTATE(buffer[deqIdx[0]].info, 0, deqIdx[0]);
                    if (deqRdy[0]) begin
                        buffer[deqIdx[0]].issued <= 1;
                    end
                end
            end
            else begin
                s1_deqRdy <= 0;
            end

            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                if (buffer[fa].vld) begin
                    buffer[fa].srcRdy <= nxtSrcRdy[fa];
                end
            end
        end
    end

    logic [`WDEF(DEPTH)] free_entry_selected[INOUTPORT_NUM];

    `SET_TRACE_OFF
    robIdx_t ages[DEPTH];
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin
            assign ages[i] = buffer[i].info.robIdx;
        end
    endgenerate
    age_schedule #(
        .WIDTH(DEPTH),
        .OUTS (INOUTPORT_NUM)
    ) u_age_schedule (
        .clk      (clk),
        .rst      (rst),
        .i_vld    (entry_ready),
        .i_ages   (ages),
        .o_vld    (deqRdy),
        .o_sel_idx(deqIdx)
    );
    `SET_TRACE_ON

    logic [`WDEF(DEPTH)] AAA_buffer_vld;

    always_comb begin
        int ca, cb, cc;
        for (ca = 0; ca < DEPTH; ca = ca + 1) begin
            AAA_buffer_vld[ca] = buffer[ca].vld;
            nxtSrcRdy[ca] = buffer[ca].srcRdy;
            for (cb = 0; cb < `NUMSRCS_INT; cb = cb + 1) begin
                // alu/mdu wake
                for (cc = 0; cc < EXTERNAL_WAKEUPNUM; cc = cc + 1) begin
                    if ((buffer[ca].info.iprs[cb] == i_ext_wk_iprd[cc]) && i_ext_wk_vec[cc]) begin
                        nxtSrcRdy[ca][cb] = 1;
                    end
                end

                for (cc = 0; cc < `LDU_NUM; cc = cc + 1) begin
                    // load wake
                    if ((buffer[ca].info.iprs[cb] == if_loadwake.wkIprd[cc]) && if_loadwake.wk[cc]) begin
                        nxtSrcRdy[ca][cb] = 1;
                    end
                end
            end
        end
    end
endmodule
