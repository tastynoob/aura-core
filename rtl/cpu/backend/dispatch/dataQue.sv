`include "core_define.svh"


// used for imm buffer, branch buffer, reorder buffer
// unorder in,unorder out(alloc id)

module dataQue #(
    parameter int DEPTH = 30,
    parameter int INPORT_NUM = 4,
    parameter int READPORT_NUM = 4,
    parameter int CLEARPORT_NUM = 4,
    parameter int COMMIT_WID = 4,
    parameter type dtype = logic[`XDEF],
    parameter int ISROB = 0
)(
    input wire clk,
    input wire rst,
    input wire i_stall, // only for rob
    // enq data
    output wire o_can_enq,
    input wire i_enq_vld, // only when enq_vld is true, dataQue can enq
    input wire[`WDEF(INPORT_NUM)] i_enq_req,
    input wire[`WDEF(INPORT_NUM)] i_enq_req_mark_finished,// only for rob
    input dtype i_enq_data[INPORT_NUM],
    output wire o_ptr_flipped[INPORT_NUM],
    output wire[`WDEF($clog2(DEPTH))] o_alloc_id[INPORT_NUM],
    // output the actually enq_vld and enq_idx (only for ftqOffset_buffer)
    output wire[`WDEF(INPORT_NUM)] o_enq_vld,
    output wire[`WDEF($clog2(DEPTH))] o_enq_idx[INPORT_NUM],

    // read data
    input wire[`WDEF($clog2(DEPTH))] i_read_dqIdx[READPORT_NUM],
    output dtype o_read_data[READPORT_NUM],
    // clear data
    input wire[`WDEF(CLEARPORT_NUM)] i_clear_vld,
    input wire[`WDEF($clog2(DEPTH))] i_clear_dqIdx[CLEARPORT_NUM],

    // used for rob commit (only for commit)
    output wire[`WDEF(COMMIT_WID)] o_willClear_vld,
    output wire[`WDEF($clog2(DEPTH))] o_willClear_idx[COMMIT_WID],
    output dtype o_willClear_data[COMMIT_WID]
);
    genvar i;
    int j;

    wire[`WDEF(INPORT_NUM)] enq_req;
    dtype enq_data[INPORT_NUM];
    reg[`WDEF($clog2(DEPTH))] enq_ptr[INPORT_NUM],head_ptr[COMMIT_WID];
    reg enq_ptr_flipped[INPORT_NUM];

    if(!ISROB) begin:gen_if
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

        redirect
        #(
            .dtype ( logic[`WDEF($clog2(DEPTH))] ),
            .NUM   ( INPORT_NUM   )
        )
        u_redirect_0(
            .i_arch_vld       ( i_enq_req       ),
            .i_arch_datas     ( enq_ptr     ),
            .o_redirect_datas ( o_alloc_id )
        );
        redirect
        #(
            .dtype ( logic ),
            .NUM   ( INPORT_NUM   )
        )
        u_redirect_1(
            .i_arch_vld       ( i_enq_req       ),
            .i_arch_datas     ( enq_ptr_flipped     ),
            .o_redirect_datas ( o_ptr_flipped )
        );

    end
    else begin:gen_else
    // if isROB, the enq_req must in order
        assign enq_req = i_enq_req;
        assign enq_data = i_enq_data;

        assign o_alloc_id = enq_ptr;
        assign o_ptr_flipped = enq_ptr_flipped;
        `ORDER_CHECK(enq_req);
    end

    dtype buffer[DEPTH];
    reg[`WDEF(DEPTH)] vld_bits;
    reg[`WDEF(DEPTH)] clear_bits;
    reg[`SDEF(DEPTH)] count;
    wire[`SDEF(DEPTH)] remaining = (DEPTH - count);
    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq && i_enq_vld ? enq_req : 0;
    wire[`SDEF(DEPTH)] real_enq_num, enq_num, clear_num;
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(INPORT_NUM)] can_clear_vld;

    assign o_enq_vld = real_enq_vld;
    assign o_enq_idx = enq_ptr;

    count_one
    #(
        .WIDTH ( INPORT_NUM     )
    )
    u_count_one_0(
        .i_a   ( i_enq_req      ),
        .o_sum ( enq_num        )
    );

    assign o_can_enq = enq_num <= remaining;

    count_one
    #(
        .WIDTH ( INPORT_NUM     )
    )
    u_count_one_1(
        .i_a   ( real_enq_vld   ),
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
        if (rst) begin
            vld_bits <= {DEPTH{1'b0}};
            clear_bits <= {DEPTH{1'b0}};
            count <= 0;
            for (j = 0; j < INPORT_NUM; j = j + 1) begin
                enq_ptr[j] <= j;
                if (ISROB) begin
                    enq_ptr_flipped[j] <= 0;
                end
            end
            for(j=0;j<COMMIT_WID;j=j+1) begin
                head_ptr[j] <= j;
            end
        end
        else begin
            count <= count + real_enq_num - clear_num;
            //enq

            for ( j = 0; j < INPORT_NUM; j = j + 1) begin
                enq_ptr[j] <= (enq_ptr[j] + real_enq_num) < DEPTH ? (enq_ptr[j] + real_enq_num) : (enq_ptr[j] + real_enq_num - DEPTH);
                if (real_enq_vld[j]) begin
                    vld_bits[enq_ptr[j]] <= true;
                    buffer[enq_ptr[j]] <= i_enq_data[j];
                end
                if ((enq_ptr[j] + real_enq_num) < DEPTH) begin
                end
                else if(ISROB) begin // flipped
                    enq_ptr_flipped[j] <= ~enq_ptr_flipped[j];
                end

                if (ISROB && real_enq_vld[j] && i_enq_req_mark_finished[j]) begin
                    clear_bits[enq_ptr[j]] <= true;
                end
            end

            // mark can clear
            for (j=0;j<CLEARPORT_NUM;j=j+1) begin
                if (i_clear_vld[j]) begin
                    clear_bits[i_clear_dqIdx[j]] <= true;
                    assert (vld_bits[i_clear_dqIdx[j]]==true);
                end
            end
            //clear/commit
            for (j=0;j<COMMIT_WID;j=j+1) begin
                if (can_clear_vld[j]) begin
                    vld_bits[head_ptr[j]] <= false;
                    clear_bits[head_ptr[j]] <= false;
                end
                head_ptr[j] <= (head_ptr[j] + clear_num) < DEPTH ? (head_ptr[j] + clear_num) : (head_ptr[j] + clear_num - DEPTH);
            end
        end
    end

    generate
        if (!ISROB) begin:gen_if
        // if is imm reorder buffer
            for(i=0;i<READPORT_NUM;i=i+1) begin:gen_for
                assign o_read_data[i] = buffer[i_read_dqIdx[i]];
            end
        end

        for (i = 0; i < COMMIT_WID; i = i + 1) begin:gen_for
            if (i==0) begin:gen_if
                assign can_clear_vld[i] = clear_bits[head_ptr[i]] & (ISROB ? !i_stall : 1);
            end
            else begin:gen_else
                assign can_clear_vld[i] = clear_bits[head_ptr[i]] & can_clear_vld[i-1];
            end
            if (ISROB) begin:gen_if
                assign o_willClear_vld[i] = can_clear_vld[i];
                assign o_willClear_idx[i] = head_ptr[i];
                assign o_willClear_data[i] = buffer[head_ptr[i]];
            end
        end
    endgenerate

    // used for waveform debug
    wire[`SDEF(DEPTH)] AAA_count = count;

    wire[`SDEF(DEPTH)] AAA_enq_num = real_enq_num;

    wire[`SDEF(DEPTH)] AAA_clear_num = clear_num;
endmodule



