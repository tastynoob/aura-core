`include "dispatch_define.svh"


`define DATAQUE_TYPE_IMM 0
`define DATAQUE_TYPE_PC 1



// used for imm buffer, pc buffer, predTakenpc buffer
module dataQue #(
    parameter int DEPTH = 30,
    parameter int INPORT_NUM = 4,
    parameter int OUTPORT_NUM = 4,
    parameter int CLEAR_WID = 4,
    parameter type dtype = logic[`XDEF],
    parameter int QUE_TYPE = 0
)(
    input wire clk,
    input wire rst,

    output wire[`WDEF(INPORT_NUM)] o_can_enq,
    input wire[`WDEF(INPORT_NUM)] i_enq_req,
    input dtype i_enq_data[INPORT_NUM],
    // read data
    input wire[`WDEF($clog2(DEPTH)-1)] i_read_dqIdx[OUTPORT_NUM],
    output dtype o_read_data[OUTPORT_NUM],
    // clear unused data (commit)
    input wire[`WDEF(OUTPORT_NUM)] i_wb_vld,
    input wire[`WDEF($clog2(DEPTH)-1)] i_wb_dqIdx[OUTPORT_NUM]
);
    genvar i;
    integer j;
    reg[`WDEF(DEPTH)] vld_bits;
    dtype buffer[DEPTH];
    reg[`WDEF($clog2(DEPTH)-1)] enq_ptr[INPORT_NUM],head_ptr;
    reg[`SDEF(DEPTH)] count;

    generate
        for (i=0;i<INPORT_NUM;i=i+1) begin:gen_for
            assign o_can_enq[i] = (DEPTH - count) > i;
        end
    endgenerate
    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq & i_enq_req;
    wire[`SDEF(DEPTH)] enq_num;

    wire[`WDEF(INPORT_NUM)] can_clear_vld;
    wire[`SDEF(DEPTH)] clear_num;
    count_one
    #(
        .WIDTH ( INPORT_NUM )
    )
    u_count_one_0(
        .i_a   ( real_enq_vld   ),
        .o_sum ( enq_num )
    );
    count_one
    #(
        .WIDTH ( INPORT_NUM )
    )
    u_count_one_1(
        .i_a   ( can_clear_vld   ),
        .o_sum ( clear_num )
    );


    always @(posedge clk) begin
        if (rst==true) begin
            vld_bits <= {DEPTH{1}};
            count <= 0;
            for (j=0;j<INPORT_NUM;j=j+1) begin
                enq_ptr[j] <= j;
            end
        end
        else begin
            count <= count + enq_num - clear_num;
            //enq
            if (|real_enq_vld) begin
                for (j=0;j<INPORT_NUM;j=j+1) begin
                    enq_ptr[j] <= enq_ptr[j] + write_num - (enq_ptr[j] < (DEPTH-INPORT_NUM+j) ? 0 : DEPTH);
                    if (real_enq_vld[j]) begin
                        vld_bits[enq_ptr[j]] <= true;
                    end
                end
            end
            //clear
            if (!can_clear_vld) begin
                head_ptr <= head_ptr + read_num - (head_ptr < (DEPTH-1) ? 0 : DEPTH);
            end
            //wb
            for (j=0;j<OUTPORT_NUM;j=j+1) begin
                if (i_wb_vld[j]) begin
                    vld_bits[i_wb_dqIdx[j]] <= false;
                end
            end
        end
    end

    generate
        for (i=0;i<CLEAR_WID;i=i+1) begin:gen_for
            if (i==0) begin:gen_if
                assign can_clear_vld[i] = vld_bits[head_ptr + i];
            end
            else begin:gen_else
                assign can_clear_vld[i] = vld_bits[head_ptr + i] & can_clear_vld[i-1];
            end
        end
    endgenerate

endmodule



