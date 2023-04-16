`include "issue_define.svh"




//use uncompressed scheme
//uncompressed scheme must use with read-regfile befor issue
//it must has the same number of in and out ports
//in genral, the fus that RS issued should has same specification
//TODO:finish wakeup logic

//unordered in,unordered out
module RS #(
    parameter int DEPTH = 8,
    parameter int INOUTPORT_NUM = 2,
    parameter int WBPORT_NUM = 6,
    parameter int RS_TYPE = 0
) (
    input wire clk,
    input wire rst,

    //enq
    output wire[`WDEF(INOUTPORT_NUM)] o_can_enq,
    input wire[`WDEF(INOUTPORT_NUM)] i_enq_req,
    input RSenqInfo_t i_RSenqInfo_enq[INOUTPORT_NUM],

    //output INOUTPORT_NUM entrys with the highest priority which is ready
    output RSdeqInfo_t o_RSdeqInfo_deq[INOUTPORT_NUM],
    output wire[`WDEF(INOUTPORT_NUM)] o_can_deq,//find can issued entry
    input wire[`WDEF(INOUTPORT_NUM)] i_deq_req,//issue req

    //writeback port
    input wire[`WDEF(WBPORT_NUM)] i_wb_vld,
    input iprIdx_t i_wb_rdIdx[WBPORT_NUM],
    input logic[`XDEF] i_wb_data
);
    genvar i;
    integer j,k;

    RSInfo_t buffer[DEPTH];
    reg[`SDEF(DEPTH)] count;
    wire[`SDEF(INOUTPORT_NUM)] enq_num,deq_num;
    wire[`WDEF(DEPTH)] entry_ready_to_issue;
    //find the entry idx of buffer which can issue
    wire[`WDEF(INOUTPORT_NUM)] enq_find_free, deq_find_ready;//is find the entry which is ready to issye
    wire[`SDEF(DEPTH)] enq_idx[INOUTPORT_NUM] ,deq_idx[INOUTPORT_NUM];//the entrys that ready to issue
    reg[`WDEF(INOUTPORT_NUM)] saved_deq_find_ready;//T0 compute and T1 use
    reg[`SDEF(DEPTH)] saved_deq_idx[INOUTPORT_NUM];
    assign o_can_deq = saved_deq_find_ready;
    wire[`WDEF(INOUTPORT_NUM)] real_enq_req = i_enq_req & o_can_enq;
    wire[`WDEF(INOUTPORT_NUM)] real_deq_req = i_deq_req & saved_deq_find_ready;
    count_one
    #(
        .WIDTH ( INOUTPORT_NUM )
    )
    u_count_one_0(
        .i_a   ( real_enq_req   ),
        .o_sum ( enq_num )
    );
    count_one
    #(
        .WIDTH ( INOUTPORT_NUM )
    )
    u_count_one_1(
        .i_a   ( real_deq_req),
        .o_sum ( deq_num )
    );
    generate
        for(i=0;i<INOUTPORT_NUM;i=i+1)begin:gen_for
            assign o_can_enq[i] = DEPTH - count > i;
        end
    endgenerate



    //update status
    always_ff @( posedge clk ) begin
        if (rst==true) begin
            for (j=0;j<INOUTPORT_NUM;j=j+1) begin
                saved_deq_find_ready[i] <= false;
            end
            count <= 0;
        end
        else begin
            count <= count + enq_num - deq_num;
            //save selected entry's Idx
            saved_deq_find_ready <= deq_find_ready;
            saved_deq_idx <= deq_idx;

            //enq and deq
            for (j=0;j<INOUTPORT_NUM;j=j+1) begin
                if (real_enq_req[j]) begin
                    buffer[enq_idx[j]].vld <= true;
                end


                if (real_deq_req[j]) begin
                    buffer[saved_deq_idx[j]].vld <= false;
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
            assign entry_ready[i] = buffer[i].vld && buffer[i].src0_ready && buffer[i].src1_ready;
        end
    endgenerate
    //FIXME: when an entry is selected to issue, we must filte this entry at ready_entry_select
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








    //wake up

    generate
        for(i=0;i<DEPTH;i=i+1) begin:gen_for
            bypass_sel
            #(
                .DEPTH    (DEPTH    ),
                .IDXWIDTH (IDXWIDTH ),
                .dtype    (dtype    )
            )
            u_bypass_sel(
            	.i_src_vld     (i_src_vld     ),
                .i_src_idx     (i_src_idx     ),
                .i_src_data    (i_src_data    ),
                .i_target_idx  (i_target_idx  ),
                .o_target_data (o_target_data )
            );

        end
    endgenerate




    generate
        for (i=0;i<INOUTPORT_NUM;i=i+1) begin:gen_for
            assign o_RSInfo_deq[i].fu_type = buffer[saved_deq_idx[i]].fu_type;
            assign o_RSInfo_deq[i].fu_type = buffer[saved_deq_idx[i]].fu_type;
            assign o_RSInfo_deq[i].fu_type = buffer[saved_deq_idx[i]].fu_type;
        end
    endgenerate

    `ORDER_CHECK(real_enq_req);
    `ORDER_CHECK(real_deq_req);
endmodule




