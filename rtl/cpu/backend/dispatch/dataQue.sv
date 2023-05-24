`include "core_define.svh"


// used for imm buffer, branch buffer, reorder buffer
// unorder in,unorder out

module dataQue #(
    parameter int DEPTH = 30,
    parameter int INPORT_NUM = 4,
    parameter int READPORT_NUM = 4,
    parameter int CLEARPORT_NUM = 4,
    parameter int WBPORT_NUM = 4,
    parameter int COMMIT_WID = 4,
    parameter type dtype = logic[`XDEF],
    parameter int ISBRANCHBUFFER = 0
)(
    input wire clk,
    input wire rst,
    // enq data
    output wire o_can_enq,
    input wire i_enq_vld, // only when enq_vld is true, dataQue can enq
    input wire[`WDEF(INPORT_NUM)] i_enq_req,
    input dtype i_enq_data[INPORT_NUM],
    output wire[`WDEF($clog2(DEPTH)-1)] o_alloc_id[INPORT_NUM],
    // read data
    input wire[`WDEF($clog2(DEPTH)-1)] i_read_dqIdx[READPORT_NUM],
    output dtype o_read_data[READPORT_NUM],
    // clear data
    input wire[`WDEF(CLEARPORT_NUM)] i_clear_vld,
    input wire[`WDEF($clog2(DEPTH)-1)] i_clear_dqIdx[CLEARPORT_NUM],

    // writeback (only for branchBuffer)
    input wire[`WDEF(WBPORT_NUM)] i_wb_vld,
    input wire[`WDEF($clog2(DEPTH)-1)] i_wb_dqIdx[WBPORT_NUM],
    input wire[`XDEF] i_wb_npc[WBPORT_NUM],
    // used for rob commit (only for commit)
    output wire[`WDEF(COMMIT_WID)] o_willClear_vld,
    output dtype o_willClear_data[COMMIT_WID]
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

    reg[`WDEF($clog2(DEPTH)-1)] enq_ptr[INPORT_NUM],head_ptr[COMMIT_WID];

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

    dtype buffer[DEPTH];
    reg[`WDEF(DEPTH)] vld_bits;
    reg[`WDEF(DEPTH)] clear_bits;
    reg[`SDEF(DEPTH)] count;
    wire[`SDEF(DEPTH)] renaming = (DEPTH - count);
    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq ? enq_req : 0;
    wire[`SDEF(DEPTH)] real_enq_num, enq_num, clear_num;
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(INPORT_NUM)] can_clear_vld;

    count_one
    #(
        .WIDTH ( INPORT_NUM     )
    )
    u_count_one_0(
        .i_a   ( i_enq_req      ),
        .o_sum ( enq_num        )
    );

    assign o_can_enq = enq_num <= renaming;

    count_one
    #(
        .WIDTH ( INPORT_NUM     )
    )
    u_count_one_1(
        .i_a   ( i_enq_vld ? real_enq_vld : 0 ),
        .o_sum ( real_enq_num   )
    );

    count_one
    #(
        .WIDTH ( INPORT_NUM     )
    )
    u_count_one_2(
        .i_a   ( can_clear_vld  ),
        .o_sum ( clear_num      )
    );

    always_ff @(posedge clk) begin
        if (rst==true) begin
            vld_bits <= 0;
            clear_bits <= {DEPTH{1'b0}};
            count <= 0;
            for (j = 0; j < INPORT_NUM; j = j + 1) begin
                enq_ptr[j] <= j;
            end
        end
        else begin
            count <= count + real_enq_num - clear_num;
            //enq
            if (i_enq_vld) begin
                for ( j = 0; j < INPORT_NUM; j = j + 1) begin
                    enq_ptr[j] <= enq_ptr[j] + real_enq_num - (enq_ptr[j] < (DEPTH-INPORT_NUM+j) ? 0 : DEPTH);
                    if (real_enq_vld[j]) begin
                        vld_bits[enq_ptr[j]] <= true;
                        buffer[enq_ptr[j]] <= i_enq_data[j];
                    end
                end
            end
            // mark can clear
            for (j=0;j<CLEARPORT_NUM;j=j+1) begin
                if (i_clear_vld[j]) begin
                    clear_bits[i_clear_dqIdx[j]] <= true;
                    assert (vld_bits[i_clear_dqIdx[j]]==true);
                end
            end
            //clear
            if (can_clear_vld[0]) begin
                for (j=0;j<COMMIT_WID;j=j+1) begin
                    if (can_clear_vld[j]) begin
                        vld_bits[head_ptr[j]] <= false;
                    end
                    head_ptr[j] <= head_ptr[j] + clear_num - (head_ptr[j] < (DEPTH - COMMIT_WID + j) ? 0 : DEPTH);
                end
            end
            // wb
            if (ISBRANCHBUFFER != 0) begin
                for (j=0;j<WBPORT_NUM;j=j+1) begin
                    if (i_wb_vld[j]) begin
                        buffer[i_wb_dqIdx[j]].npc <= i_wb_npc[j];
                        assert (vld_bits[i_wb_dqIdx[j]]==true);
                    end
                end
            end
        end
    end

    generate
        for (i = 0; i < COMMIT_WID; i = i + 1) begin:gen_for
            if (i==0) begin:gen_if
                assign can_clear_vld[i] = vld_bits[head_ptr[i]] & clear_bits[head_ptr[i]];
            end
            else begin:gen_else
                assign can_clear_vld[i] = (vld_bits[head_ptr[i]] & clear_bits[head_ptr[i]]) & can_clear_vld[i-1];
            end
            assign o_willClear_vld[i] = can_clear_vld[i];
            assign o_willClear_data[i] = buffer[head_ptr[i]];
        end
    endgenerate
endmodule



