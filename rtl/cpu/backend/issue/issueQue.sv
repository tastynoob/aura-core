`include "core_define.svh"


typedef struct {
    logic vld; //unused in compressed RS
    logic issued; // flag issued
    logic spec_wakeup; // flag spec wakeup
    logic[`WDEF(`NUMSRCS_INT)] src_rdy; // which src is ready
    logic[`WDEF(`NUMSRCS_INT)] src_spec_rdy; // which src is speculative ready

    exeInfo_t info;
} IQEntry;

//use uncompressed scheme
//uncompressed scheme must use with read-regfile befor issue
//it must has the same number of in and out ports
//in genral, the fus that RS issued should has same specification
//TODO:finish speculative wakeup logic

//DESIGN
//only when readRegfile successed, the IQentry can be clear
//if we want to impletement inst excute back to back
//we need wakeup earlier (speculative wakeup)
//
//when one inst was selected
//we can wakeup other insts in one cycle
//if one inst was speculative wakeup and read data incomplete
//we need to clear issued flag
//
// if the fus was handled by IQ is singleCycle execute
// it's speculative wakeup always right

//unordered in,unordered out
module issueQue #(
    parameter int DEPTH = 8,
    parameter int INOUTPORT_NUM = 2,
    parameter int EXTERNAL_WAKEUPNUM = 2,
    parameter int WBPORT_NUM = 6,
    //is or not enable internal wakeup
    parameter int INTERNAL_WAKEUP = 1,
    parameter int SINGLEEXE = 0
) (
    input wire clk,
    input wire rst,

    input i_stall,

    //enq
    output wire o_can_enq,
    input wire[`WDEF(INOUTPORT_NUM)] i_enq_req,
    input exeInfo_t i_enq_exeInfo[INOUTPORT_NUM],
    input wire[`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INOUTPORT_NUM],

    //output INOUTPORT_NUM entrys with the highest priority which is ready
    output wire[`WDEF(INOUTPORT_NUM)] o_can_issue,//find can issued entry
    output wire[`WDEF($clog2(DEPTH))] o_issue_idx[INOUTPORT_NUM],
    output exeInfo_t o_issue_exeInfo[INOUTPORT_NUM],

    // clear entry's vld bit (issue successed)
    input wire[`WDEF(INOUTPORT_NUM)] i_issue_finished_vec,
    // replay entry's issued bit (issue failed)
    input wire[`WDEF(INOUTPORT_NUM)] i_issue_replay_vec,
    // feedback from readRegfile which is or not successed
    input wire[`WDEF($clog2(DEPTH))] i_feedback_idx[INOUTPORT_NUM],

    //export internal wakeup signal
    output wire[`WDEF(INOUTPORT_NUM)] o_export_wakeup_vld,
    output iprIdx_t o_export_wakeup_rdIdx[INOUTPORT_NUM],

    //external wakeup source (speculative arousal)
    input wire[`WDEF(EXTERNAL_WAKEUPNUM)] i_ext_wakeup_vld,
    input iprIdx_t i_ext_wakeup_rdIdx[EXTERNAL_WAKEUPNUM],

    //wb wakeup port (must be correct)
    input wire[`WDEF(WBPORT_NUM)] i_wb_vld,
    input iprIdx_t i_wb_rdIdx[WBPORT_NUM]
);

    genvar i;

    //used for spec wakeup
    localparam unsigned wakeup_source_num = ((INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0) + EXTERNAL_WAKEUPNUM);

    IQEntry buffer[DEPTH];

    //find the entry idx of buffer which can issue
    logic[`WDEF(INOUTPORT_NUM)] enq_find_free, deq_find_ready;//is find the entry which is ready to issye
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
    generate
        genvar temp_idx;
        for (i=0;i<wakeup_source_num;i=i+1) begin: gen_for
            if (INTERNAL_WAKEUP==1 && i < INOUTPORT_NUM) begin : gen_internal_wakeup
                //internal wakeup source
                assign wakeup_src_vld[i] = deq_find_ready[i] & buffer[deq_idx[i]].info.rd_wen;
                assign wakeup_rdIdx[i] = buffer[deq_idx[i]].info.iprd_idx;
            end
            else begin: gen_external_wakeup
                assign temp_idx = i - (INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0);
                //external wakeup source
                assign wakeup_src_vld[i] = i_ext_wakeup_vld[temp_idx];
                assign wakeup_rdIdx[i] = i_ext_wakeup_rdIdx[temp_idx];
            end
        end
        //export internal wakeup signal
        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for
            assign o_export_wakeup_vld[i] = deq_find_ready[i] & buffer[deq_idx[i]].info.rd_wen;
            assign o_export_wakeup_rdIdx[i] = buffer[deq_idx[i]].info.iprd_idx;
        end
    endgenerate


    //update status
    always_ff @( posedge clk ) begin
        int fa,fb,fc;
        if (rst) begin
            for (fa=0;fa<INOUTPORT_NUM;fa=fa+1) begin
                saved_deq_find_ready[fa] <= false;
            end
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
                    buffer[enq_idx[fa]].vld <= true;
                    buffer[enq_idx[fa]].info <= i_enq_exeInfo[fa];
                    buffer[enq_idx[fa]].issued <= 0;
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
                    else if ((SINGLEEXE != 0) && i_issue_replay_vec[fa]) begin
                        assert(buffer[i_feedback_idx[fa]].vld);
                        assert(buffer[i_feedback_idx[fa]].src_spec_rdy == {`NUMSRCS_INT{1'b1}});
                        buffer[deq_idx[fa]].issued <= false;
                        buffer[i_feedback_idx[fa]].src_spec_rdy <= buffer[i_feedback_idx[fa]].src_rdy;
                    end
                end
                assert(SINGLEEXE ? !(i_issue_replay_vec) : 1);
            end
        end


        for(fa=0;fa<DEPTH;fa=fa+1) begin
            for (fb=0;fb<`NUMSRCS_INT;fb=fb+1) begin
                //wb wakeup
                for (fc=0;fc<WBPORT_NUM;fc=fc+1) begin
                    if ((buffer[fa].info.iprs_idx[fb] == i_wb_rdIdx[fc]) && i_wb_vld[fc]) begin
                        buffer[fa].src_rdy[fb] <= true;
                    end
                end
                //spec wakeup
                for (fc=0;fc<wakeup_source_num;fc=fc+1) begin
                    if ((buffer[fa].info.iprs_idx[fb] == wakeup_rdIdx[fc]) && wakeup_src_vld[fc]) begin
                        buffer[fa].src_spec_rdy[fb] <= true;
                    end
                end
            end
        end
    end

    //select: find ready entry and find free entry
    //TODO: now the issue scheduler is random-select
    //we need to replace this to age-select
    logic[`WDEF(DEPTH)] free_entry_selected[INOUTPORT_NUM];
    logic[`WDEF(DEPTH)] ready_entry_selected[INOUTPORT_NUM];
    wire[`WDEF(DEPTH)] entry_ready;

    generate
        for(i=0;i<DEPTH;i=i+1) begin:gen_for
            assign entry_ready[i] = buffer[i].vld && ((&buffer[i].src_rdy) || (&buffer[i].src_spec_rdy)) && (buffer[i].issued == false);
        end
    endgenerate

    //select
    always_comb begin
        int ca,cb;
        for (cb=DEPTH-1;cb>=0;cb=cb-1) begin
            free_entry_selected[0][cb] = false;
            ready_entry_selected[0][cb] = false;
        end
        for (ca=0;ca<INOUTPORT_NUM;ca=ca+1) begin
            enq_idx[ca]=0;
            enq_find_free[ca]=false;
            deq_idx[ca]=0;
            deq_find_ready[ca]=false;

            if (ca==0) begin
                for (cb=DEPTH-1;cb>=0;cb=cb-1) begin
                    //select free entry
                    if (!buffer[cb].vld && i_enq_req[ca]) begin
                        free_entry_selected[ca][cb] = true;
                        enq_idx[ca] = cb;
                        enq_find_free[ca] = true;
                    end
                    //select ready entry
                    if (entry_ready[cb]) begin
                        ready_entry_selected[ca][cb] = true;
                        deq_idx[ca] = cb;
                        deq_find_ready[ca] = true;
                    end
                end
            end
            else begin
                free_entry_selected[ca] = free_entry_selected[ca-1];
                ready_entry_selected[ca] = ready_entry_selected[ca-1];
                for (cb=DEPTH-1;cb>=0;cb=cb-1) begin
                    //select free entry
                    if ((free_entry_selected[ca-1][cb] == false) && (!buffer[cb].vld) && i_enq_req[ca]) begin
                        free_entry_selected[ca][cb] = true;
                        enq_idx[ca] = cb;
                        enq_find_free[ca] = true;
                    end
                    //select ready entry
                    if ((ready_entry_selected[ca-1][cb] == false) && entry_ready[cb]) begin
                        ready_entry_selected[ca][cb] = true;
                        deq_idx[ca] = cb;
                        deq_find_ready[ca] = true;
                    end
                end
            end
        end
    end

    generate
        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for
            assign o_issue_exeInfo[i] = buffer[saved_deq_idx[i]].info;
        end
    endgenerate

    `ASSERT((|(i_issue_finished_vec & i_issue_replay_vec)) == 0);
    `ASSERT(wakeup_source_num <= WBPORT_NUM  );
endmodule




