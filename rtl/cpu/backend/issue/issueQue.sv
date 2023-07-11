`include "core_define.svh"




//use uncompressed scheme
//uncompressed scheme must use with read-regfile befor issue
//it must has the same number of in and out ports
//in genral, the fus that RS issued should has same specification
//TODO:finish speculative wakeup logic

//DESIGN
//only when readRegfile successed, the entry of rs can be clear
//if we want to impletement inst excute back to back
//we need wakeup earlier (speculative wakeup)
//
//when one inst was selected
//we can wakeup other insts in one cycle
//if one inst was speculative wakeup and actually it was not ready
//we need to clear issued flag

//unordered in,unordered out
module issueQue #(
    parameter int DEPTH = 8,
    parameter int INOUTPORT_NUM = 2,
    parameter int EXTERNAL_WAKEUPNUM = 2,
    parameter int WBPORT_NUM = 6,
    //is or not enable internal wakeup
    parameter int INTERNAL_WAKEUP = 1
) (
    input wire clk,
    input wire rst,

    //enq
    output wire[`WDEF(INOUTPORT_NUM)] o_can_enq,
    input wire[`WDEF(INOUTPORT_NUM)] i_enq_req,
    input RSenqInfo_t i_RSenqInfo_enq[INOUTPORT_NUM],

    //output INOUTPORT_NUM entrys with the highest priority which is ready
    output RSdeqInfo_t o_RSdeqInfo_deq[INOUTPORT_NUM],
    output wire[`WDEF($clog2(DEPTH))] o_issue_idx,
    output wire[`WDEF(INOUTPORT_NUM)] o_can_issue,//find can issued entry

    // feedback from readRegfile which is or not successed
    input wire[`WDEF($clog2(DEPTH))] i_feedback_idx[INOUTPORT_NUM],
    // clear entry's vld bit (issue successed)
    input wire[`WDEF(INOUTPORT_NUM)] i_deq_vld,//issue req
    // clear entry's issued bit (issue failed)
    input wire[`WDEF(INOUTPORT_NUM)] i_replay_vld,

    //export internal wakeup signal
    output wire[`WDEF(INOUTPORT_NUM)] o_export_wakeup_vld,
    output iprIdx o_export_wakeup_rdIdx[INOUTPORT_NUM],

    //external wakeup source (not necessarily correct)
    input wire[`WDEF(EXTERNAL_WAKEUPNUM)] i_ext_wakeup_vld,
    input iprIdx_t i_ext_wakeup_rdIdx[EXTERNAL_WAKEUPNUM],

    //wb wakeup port (must be correct)
    input wire[`WDEF(WBPORT_NUM)] i_wb_vld,
    input iprIdx_t i_wb_rdIdx[WBPORT_NUM]
);

    genvar i;
    integer j,k,p;
    //used for spec wakeup
    int wakeup_source_num = ((INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0) + EXTERNAL_WAKEUPNUM);

    RSEntry_t buffer[DEPTH];
    wire[`SDEF(INOUTPORT_NUM)] enq_num,deq_num;
    wire[`WDEF(DEPTH)] entry_ready_to_issue;
    //find the entry idx of buffer which can issue
    wire[`WDEF(INOUTPORT_NUM)] enq_find_free, deq_find_ready;//is find the entry which is ready to issye
    wire[`SDEF(DEPTH)] enq_idx[INOUTPORT_NUM] ,deq_idx[INOUTPORT_NUM];//the entrys that ready to issue
    reg[`WDEF(INOUTPORT_NUM)] saved_deq_find_ready;//T0 compute and T1 use
    reg[`SDEF(DEPTH)] saved_deq_idx[INOUTPORT_NUM];
    assign o_can_issue = saved_deq_find_ready;
    assign o_issue_idx = saved_deq_idx;
    assign o_can_enq = enq_find_free;
    wire[`WDEF(INOUTPORT_NUM)] real_enq_req = enq_find_free & i_enq_req;

    //spec wakeup source
    wire[`WDEF(wakeup_source_num)] wakeup_src_vld;
    iprIdx_t wakeup_rdIdx[wakeup_source_num];
    generate
        genvar temp_idx;
        for (i=0;i<wakeup_source_num;i=i+1) begin: gen_for
            if (INTERNAL_WAKEUP==1 && i < INOUTPORT_NUM) begin : gen_internal_wakeup
                //internal wakeup source
                assign wakeup_src_vld[i] = deq_find_ready[i] & buffer[deq_idx[i]].rd_wen;
                assign wakeup_rdIdx[i] = buffer[deq_idx[i]].rdIdx;
            end
            else begin: gen_external_wakeup
                assign temp = i - (INTERNAL_WAKEUP == 1 ? INOUTPORT_NUM : 0);
                //external wakeup source
                assign wakeup_src_vld[i] = i_ext_wakeup_vld[temp];
                assign wakeup_rdIdx[i] = i_ext_wakeup_rdIdx[temp];
            end
        end
        //export internal wakeup signal
        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for
            assign o_export_wakeup_vld[i] = deq_find_ready[i] & buffer[deq_idx[i]].rd_wen;
            assign o_export_wakeup_rdIdx[i] = buffer[deq_idx[i]].rdIdx;
        end
    endgenerate


    //update status
    always_ff @( posedge clk ) begin
        if (rst==true) begin
            for (j=0;j<INOUTPORT_NUM;j=j+1) begin
                saved_deq_find_ready[i] <= false;
            end
            for (j=0;j<DEPTH;j=j+1) begin
                buffer[j].vld <= false;
            end
        end
        else begin
            //save selected entry's Idx
            saved_deq_find_ready <= deq_find_ready;
            saved_deq_idx <= deq_idx;

            for (j=0;j<INOUTPORT_NUM;j=j+1) begin
                //enq
                if (real_enq_req[j]) begin
                    buffer[enq_idx[j]].vld <= true;
                    //TODO: finish it
                end

                //deq
                if (i_deq_vld[j] && buffer[i_feedback_idx[j]].vld) begin
                    buffer[i_feedback_idx[j]].vld <= false;
                end

                //select and issue(set issued)
                if (deq_find_ready[j]==true) begin
                    buffer[deq_idx[j]].issued <= true;
                end

                //replay
                if (i_replay_vld[j] && buffer[i_feedback_idx[j]].vld) begin
                    buffer[deq_idx[j]].issued <= false;
                    buffer[i_feedback_idx[j]].src_spec_rdy <= buffer[i_feedback_idx[j]].src_rdy;
                end
            end
            //spec wakeup
            for(j=0;j<DEPTH;j=j+1) begin
                for (k=0;k<`NUMSRCS_INT;k=k+1) begin
                    for (p=0;p<wakeup_source_num;p=p+1) begin
                        if ((buffer[j].rsIdx[k] == wakeup_rdIdx[p]) && wakeup_src_vld[p]) begin
                            buffer[j].src_spec_rdy[k] <= true;
                        end
                    end
                end
            end
            //wb wakeup
            for(j=0;j<DEPTH;j=j+1) begin
                for (k=0;k<`NUMSRCS_INT;k=k+1) begin
                    for (p=0;p<wakeup_source_num;p=p+1) begin
                        if ((buffer[j].rsIdx[k] == i_wb_rdIdx[p]) && i_wb_vld[p]) begin
                            buffer[j].src_rdy[k] <= true;
                        end
                    end
                end
            end
        end
    end

    //select: find ready entry and find free entry
    //TODO: now the issue scheduler is random-select
    //we need to replace this to age-select
    wire[`WDEF(DEPTH)] free_entry_selected[INOUTPORT_NUM];
    wire[`WDEF(DEPTH)] ready_entry_selected[INOUTPORT_NUM];
    wire[`WDEF(DEPTH)] entry_ready;

    generate
        for(i=0;i<DEPTH;i=i+1) begin:gen_for
            assign entry_ready[i] = buffer[i].vld && ((&buffer[i].src_rdy) || (&buffer[i].src_spec_rdy)) && (buffer[i].issued == false);
        end
    endgenerate

    //select
    always_comb begin
        for (j=0;j<INOUTPORT_NUM;j=j+1) begin
            for (k=DEPTH-1;k>=0;k=k-1) begin
                free_entry_selected[j][k] = false;
                ready_entry_selected[j][k] = false;
            end
        end
        for (j=0;j<INOUTPORT_NUM;j=j+1) begin
            if (j==0) begin
                deq_idx[j]=0;
                deq_find_ready[j]=false;
                enq_idx[j]=0;
                enq_find_free[j]=false;
                for (k=DEPTH-1;k>=0;k=k-1) begin
                    //select free entry
                    if (!buffer[k].vld) begin
                        free_entry_selected[j][k] = true;
                        enq_idx[j] = k;
                        enq_find_free[j] = true;
                    end
                    //select ready entry
                    if (entry_ready[k]) begin
                        ready_entry_selected[j][k] = true;
                        deq_idx[j] = k;
                        deq_find_ready[j] = true;
                    end
                end
            end
            else begin
                deq_idx[j]=0;
                deq_find_ready[j]=false;
                enq_idx[j]=0;
                enq_find_free[j]=false;
                for (k=DEPTH-1;k>=0;k=k-1) begin
                    //select free entry
                    if ((free_entry_selected[j-1][k] == false) && (!buffer[k].vld)) begin
                        free_entry_selected[j][k] = true;
                        enq_idx[j] = k;
                        enq_find_free[j] = true;
                    end
                    //select ready entry
                    if ((ready_entry_selected[j-1][k] == false) && entry_ready[k]) begin
                        ready_entry_selected[j][k] = true;
                        deq_idx[j] = k;
                        deq_find_ready[j] = true;
                    end
                end
            end
        end
    end





    generate
        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for
            assign o_RSInfo_deq[i].micOp_type = buffer[saved_deq_idx[i]].micOp_type;
        end
    endgenerate

    `ORDER_CHECK(real_enq_req);
    `ASSERT((|(i_deq_vld & i_replay_vld)) != true);
    `ASSERT(wakeup_source_num <= WBPORT_NUM  );
endmodule




