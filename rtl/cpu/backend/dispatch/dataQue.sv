`include "dispatch_define.svh"


`define DATAQUE_TYPE_IMM 0
`define DATAQUE_TYPE_PC 1



// used for imm buffer, pc buffer, predTakenpc buffer
// unorder in,unorder out

module dataQue #(
    parameter int DEPTH = 30,
    parameter int INPORT_NUM = 4,
    parameter int READPORT_NUM = 4,
    parameter int CLEAR_WID = 4,
    parameter type dtype = logic[`XDEF],
    parameter int QUE_TYPE = 0
)(
    input wire clk,
    input wire rst,

    output wire o_can_enq,
    input wire[`WDEF(INPORT_NUM)] i_enq_req,
    input dtype i_enq_data[INPORT_NUM],
    output wire[`WDEF($clog2(DEPTH)-1)] o_alloc_id[INPORT_NUM],
    // read data
    input wire[`WDEF($clog2(DEPTH)-1)] i_read_dqIdx[READPORT_NUM],
    output dtype o_read_data[READPORT_NUM],
    // clear unused data (commit)
    input wire[`WDEF(READPORT_NUM)] i_wb_vld,
    input wire[`WDEF($clog2(DEPTH)-1)] i_wb_dqIdx[READPORT_NUM]
);
    genvar i;
    integer j;

    wire[`WDEF(INPORT_NUM)] enq_req;
    dtype enq_data[INPORT_NUM];


    reorder
    #(
        .dtype ( dtype ),
        .NUM   ( INPORT_NUM   )
    )
    u_reorder(
    	.i_data_vld      ( i_enq_req      ),
        .i_datas         ( i_enq_data         ),
        .o_data_vld      ( enq_req      ),
        .o_reorder_datas ( enq_data )
    );

    reg[`WDEF($clog2(DEPTH)-1)] enq_ptr[INPORT_NUM],head_ptr[CLEAR_WID];

    redirect
    #(
        .dtype ( logic[`WDEF($clog2(DEPTH)-1)] ),
        .NUM   ( INPORT_NUM   )
    )
    u_redirect(
    	.i_arch_vld       ( i_enq_req       ),
        .i_arch_datas     ( enq_ptr     ),
        .o_redirect_datas ( o_alloc_id )
    );


    reg[`WDEF(DEPTH)] vld_bits;
    reg[`WDEF(DEPTH)] wb_bits;
    dtype buffer[DEPTH];
    reg[`SDEF(DEPTH)] count;

    assign o_can_enq = (DEPTH - count) >= INPORT_NUM;
    generate
        for (i=0;i<INPORT_NUM;i=i+1) begin:gen_for

        end
    endgenerate
    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq ? enq_req : 0;
    wire[`SDEF(DEPTH)] enq_num;
    /* verilator lint_off UNOPTFLAT */
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
            vld_bits <= 0;
            wb_bits <= {DEPTH{1'b1}};
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
                    enq_ptr[j] <= enq_ptr[j] + enq_num - (enq_ptr[j] < (DEPTH-INPORT_NUM+j) ? 0 : DEPTH);
                    if (real_enq_vld[j]) begin
                        vld_bits[enq_ptr[j]] <= true;
                    end
                end
            end
            //clear
            if (can_clear_vld[0]) begin
                for (j=0;j<CLEAR_WID;j=j+1) begin
                    head_ptr[j] <= head_ptr[j] + clear_num - (head_ptr[j] < (DEPTH - CLEAR_WID + j) ? 0 : DEPTH);
                    if (can_clear_vld[j]) begin
                        vld_bits[head_ptr[j]] <= false;
                    end
                end
            end
            //wb
            for (j=0;j<READPORT_NUM;j=j+1) begin
                if (i_wb_vld[j]) begin
                    wb_bits[i_wb_dqIdx[j]] <= false;
                end
            end
        end
    end

    generate
        for (i=0;i<CLEAR_WID;i=i+1) begin:gen_for
            if (i==0) begin:gen_if
                assign can_clear_vld[i] = vld_bits[head_ptr[i]] & wb_bits[head_ptr[i]];
            end
            else begin:gen_else
                assign can_clear_vld[i] = (vld_bits[head_ptr[i]] & wb_bits[head_ptr[i]]) & can_clear_vld[i-1];
            end
        end
    endgenerate


    

endmodule



