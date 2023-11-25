`include "backend_define.svh"



// load IQ only have 1 src
module issueQue_ld #(
    parameter int DEPTH = 8,
    parameter int INOUTPORT_NUM = 2,
    parameter int EXTERNAL_WAKEUPNUM = 2,
    parameter int WBPORT_NUM = 6,
    //is or not enable internal wakeup
    parameter int INTERNAL_WAKEUP = 1,
    parameter int SINGLEEXE = 0,
    parameter int HASDEST = 1,
    parameter int NUMSRCS = 1
) (
    input wire clk,
    input wire rst,

    input i_stall,

    //enq
    output wire o_can_enq,
    input wire[`WDEF(INOUTPORT_NUM)] i_enq_req,
    input memExeInfo_t i_enq_exeInfo[INOUTPORT_NUM],
    input wire[`WDEF(NUMSRCS)] i_enq_iprs_rdy[INOUTPORT_NUM],
    input wire i_enq_memdep_rdy[INOUTPORT_NUM],

    //output INOUTPORT_NUM entrys with the highest priority which is ready
    output wire[`WDEF(INOUTPORT_NUM)] o_can_issue,//find can issued entry
    output wire[`WDEF($clog2(DEPTH))] o_issue_idx[INOUTPORT_NUM],
    output memExeInfo_t o_issue_exeInfo[INOUTPORT_NUM],

    // clear entry's vld bit (issue successed)
    input wire[`WDEF(INOUTPORT_NUM)] i_issue_finished_vec,
    // replay entry's issued bit (issue failed)
    input wire[`WDEF(INOUTPORT_NUM)] i_issue_replay_vec,
    // feedback from readRegfile which is or not successed
    input wire[`WDEF($clog2(DEPTH))] i_feedback_idx[INOUTPORT_NUM],

    //export internal wakeup signal
    output wire[`WDEF(INOUTPORT_NUM)] o_export_wakeup_vld,
    output iprIdx_t o_export_wakeup_rdIdx[INOUTPORT_NUM],

    //external wakeup source (speculative wakeup)
    input wire[`WDEF(EXTERNAL_WAKEUPNUM)] i_ext_wakeup_vld,
    input iprIdx_t i_ext_wakeup_rdIdx[EXTERNAL_WAKEUPNUM],

    //wb wakeup port (must be correct)
    input wire[`WDEF(WBPORT_NUM)] i_wb_vld,
    input iprIdx_t i_wb_rdIdx[WBPORT_NUM],

    // store issue
    input wire[`WDEF(`STORE_ISSUE_WIDTH)] i_store_issue,
    input robIdx_t i_store_robIdx[`STORE_ISSUE_WIDTH]
);

    genvar i;

    typedef struct {
        logic vld; //unused in compressed RS
        logic issued; // flag issued
        logic memdep_rdy;
        logic[`WDEF(NUMSRCS)] src_rdy; // which src is ready
        logic[`WDEF(NUMSRCS)] src_spec_rdy; // which src is speculative ready

        memExeInfo_t info;
    } IQEntry;

    //used for spec wakeup
    localparam unsigned wakeup_source_num = ((INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0) + EXTERNAL_WAKEUPNUM);

    IQEntry buffer[DEPTH];
    logic[`WDEF(DEPTH)] nxt_memdep_rdy;
    logic[`WDEF(NUMSRCS)] nxt_src_rdy[DEPTH], nxt_src_spec_rdy[DEPTH];

    //find the entry idx of buffer which can issue
    logic[`WDEF(INOUTPORT_NUM)] enq_find_free, deq_find_ready;//is find the entry which is ready to issue
    logic[`WDEF($clog2(DEPTH))] enq_idx[INOUTPORT_NUM] ,deq_idx[INOUTPORT_NUM];//the entrys that ready to issue
    reg[`WDEF(INOUTPORT_NUM)] saved_deq_find_ready;//T0 compute and T1 use
    reg[`WDEF($clog2(DEPTH))] saved_deq_idx[INOUTPORT_NUM];

    assign o_can_issue = saved_deq_find_ready;
    assign o_issue_idx = saved_deq_idx;
    assign o_can_enq = &enq_find_free;

    wire[`WDEF(INOUTPORT_NUM)] real_enq_req = enq_find_free & i_enq_req;

    //spec wakeup source
    wire[`WDEF(wakeup_source_num)] wakeup_src_vld;
    iprIdx_t wakeup_rdIdx[wakeup_source_num];


    wire[`WDEF(DEPTH)] entry_ready;
    generate
        for (i=0;i<wakeup_source_num;i=i+1) begin: gen_for0
            if ((INTERNAL_WAKEUP==1) && (i < INOUTPORT_NUM)) begin : gen_internal_wakeup
                //internal wakeup source
                assign wakeup_src_vld[i] = deq_find_ready[i] && buffer[deq_idx[i]].info.rd_wen;
                assign wakeup_rdIdx[i] = buffer[deq_idx[i]].info.iprd_idx;
            end
            else begin: gen_external_wakeup
                //external wakeup source
                assign wakeup_src_vld[i] = i_ext_wakeup_vld[i - (INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0)];
                assign wakeup_rdIdx[i] = i_ext_wakeup_rdIdx[i - (INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0)];
            end
            `ASSERT(wakeup_src_vld[i] ? wakeup_rdIdx[i] < `IPHYREG_NUM : 1);
        end
        //export internal wakeup signal
        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for1
            assign o_export_wakeup_vld[i] = buffer[deq_idx[i]].vld && deq_find_ready[i] && buffer[deq_idx[i]].info.rd_wen;
            assign o_export_wakeup_rdIdx[i] = buffer[deq_idx[i]].info.iprd_idx;
        end

        for(i=0;i<DEPTH;i=i+1) begin : gen_for2
            assign entry_ready[i] = buffer[i].vld && (&(buffer[i].src_rdy | buffer[i].src_spec_rdy)) && (buffer[i].issued == 0);
        end

        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for4
            assign o_issue_exeInfo[i] = buffer[saved_deq_idx[i]].info;
        end
    endgenerate


    //update status
    always_ff @( posedge clk ) begin
        int fa,fb,fc;
        if (rst) begin
            saved_deq_find_ready <= 0;
            for (fa=0;fa<DEPTH;fa=fa+1) begin
                buffer[fa].vld <= false;
            end
        end
        else begin
            //save selected entry's Idx
            saved_deq_find_ready <= deq_find_ready;
            saved_deq_idx <= deq_idx;

            for (fa=0;fa<INOUTPORT_NUM;fa=fa+1) begin
                //enq
                if (real_enq_req[fa]) begin
                    assert(buffer[enq_idx[fa]].vld == 0);
                    buffer[enq_idx[fa]].vld <= true;
                    buffer[enq_idx[fa]].info <= i_enq_exeInfo[fa];
                    buffer[enq_idx[fa]].issued <= 0;
                    buffer[enq_idx[fa]].memdep_rdy <= i_enq_memdep_rdy[fa];
                    buffer[enq_idx[fa]].src_rdy <= i_enq_iprs_rdy[fa];
                    buffer[enq_idx[fa]].src_spec_rdy <= i_enq_iprs_rdy[fa];
                end
                if (!i_stall) begin
                    //select and issue(set issued)
                    if (deq_find_ready[fa]==true) begin
                        buffer[deq_idx[fa]].issued <= true;
                    end

                    //deq
                    if (i_issue_finished_vec[fa]) begin
                        assert(buffer[i_feedback_idx[fa]].vld);
                        buffer[i_feedback_idx[fa]].vld <= false;
                    end
                    //replay
                    else if ((!SINGLEEXE) && i_issue_replay_vec[fa]) begin
                        assert(buffer[i_feedback_idx[fa]].vld);
                        assert(buffer[i_feedback_idx[fa]].src_spec_rdy == {NUMSRCS{1'b1}});
                        buffer[deq_idx[fa]].issued <= false;
                        buffer[i_feedback_idx[fa]].src_spec_rdy <= buffer[i_feedback_idx[fa]].src_rdy;
                    end
                end
                assert(SINGLEEXE ? !(|i_issue_replay_vec) : 1);
            end

            for (fa=0;fa<DEPTH;fa=fa+1) begin
                if (buffer[fa].vld) begin
                    buffer[fa].memdep_rdy <= nxt_memdep_rdy[fa];
                    buffer[fa].src_rdy <= nxt_src_rdy[fa];
                    buffer[fa].src_spec_rdy <= nxt_src_spec_rdy[fa];
                end
            end
        end
    end

    //select: find ready entry and find free entry
    //TODO: now the issue scheduler is random-select
    //we need to replace this to age-select
    logic[`WDEF(DEPTH)] free_entry_selected[INOUTPORT_NUM];

    //select
    always_comb begin
        int ca,cb;
        free_entry_selected[0] = 0;
        for (ca=0;ca<INOUTPORT_NUM;ca=ca+1) begin
            enq_idx[ca]=0;
            enq_find_free[ca]=0;
            deq_idx[ca]=0;

            if (ca==0) begin
                for (cb=DEPTH-1;cb>=0;cb=cb-1) begin
                    //select free entry
                    if (!buffer[cb].vld) begin
                        enq_idx[ca] = cb;
                        enq_find_free[ca] = 1;
                    end
                end
                free_entry_selected[ca][enq_idx[ca]] = enq_find_free[ca];
                //ready_entry_selected[ca][deq_idx[ca]] = deq_find_ready[ca];
            end
            else begin
                free_entry_selected[ca] = free_entry_selected[ca-1];
                for (cb=DEPTH-1;cb>=0;cb=cb-1) begin
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

`SET_TRACE_OFF
    robIdx_t ages[DEPTH];
    generate
        for (i=0;i<DEPTH;i=i+1) begin : gen_for3
            assign ages[i] = buffer[i].info.rob_idx;
        end
    endgenerate
    age_schedule
    #(
        .WIDTH ( DEPTH ),
        .OUTS  ( INOUTPORT_NUM  )
    )
    u_age_schedule(
        .clk       ( clk ),
        .rst       ( rst ),
        .i_vld     ( entry_ready ),
        .i_ages    ( ages    ),
        .o_vld     ( deq_find_ready     ),
        .o_sel_idx ( deq_idx )
    );
`SET_TRACE_ON
    `ASSERT((i_issue_finished_vec & i_issue_replay_vec) == 0);
    `ASSERT(wakeup_source_num <= WBPORT_NUM  );

    logic[`WDEF(DEPTH)] AAA_buffer_vld;

    // wakeup
    always_comb begin
        int ca,cb,cc;
        for(ca=0;ca<DEPTH;ca=ca+1) begin
            AAA_buffer_vld[ca] = buffer[ca].vld;
            nxt_src_rdy[ca] = buffer[ca].src_rdy;
            nxt_src_spec_rdy[ca] = buffer[ca].src_spec_rdy;
            nxt_memdep_rdy[ca] = 0;
            for (cb=0;cb<NUMSRCS;cb=cb+1) begin
                //wb wakeup
                for (cc=0;cc<WBPORT_NUM;cc=cc+1) begin
                    if ((buffer[ca].info.iprs_idx[cb] == i_wb_rdIdx[cc]) && i_wb_vld[cc]) begin
                        nxt_src_rdy[ca][cb] = 1;
                    end
                end
                //spec wakeup
                for (cc=0;cc<wakeup_source_num;cc=cc+1) begin
                    if ((buffer[ca].info.iprs_idx[cb] == wakeup_rdIdx[cc]) && wakeup_src_vld[cc]) begin
                        nxt_src_spec_rdy[ca][cb] = 1;
                    end
                end
            end
            for (cb=0;cb<`STORE_ISSUE_WIDTH;cb=cb+1) begin
                if (i_store_issue[cb] && (buffer[ca].info.dep_robIdx == i_store_robIdx[cb])) begin
                    nxt_memdep_rdy[ca] = 1;
                end
            end
        end
    end
endmodule




