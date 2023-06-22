`include "base.svh"
`include "funcs.svh"
import funcs::*;

//unsafed fifo
//ordered in out
module fifo #(
    parameter type dtype = logic,
    parameter int INPORT_NUM = 4,
    parameter int OUTPORT_NUM = 4,
    parameter int DEPTH = 32,
    parameter int USE_INIT = 0,
    // only for rename
    parameter int USE_RENAME = 0,
    parameter int COMMIT_WID = 0
) (
    input dtype init_data[DEPTH],
    input wire clk,
    input wire rst,
    input wire i_flush,
    // enq
    output wire o_can_enq,
    input wire i_enq_vld, // only when enq_vld is true, can enq
    input wire [`WDEF(INPORT_NUM)] i_enq_req,
    input dtype i_enq_data[INPORT_NUM],
    // deq
    output wire [`WDEF(OUTPORT_NUM)] o_can_deq,
    input wire [`WDEF(OUTPORT_NUM)] i_deq_req,
    output dtype o_deq_data[OUTPORT_NUM],
    // DESIGN: rename restore
    // resteer (only for rename restore)
    input wire i_resteer_vld,
    // commit (only for rename restore)
    input wire[`WDEF(COMMIT_WID)] i_commit_vld
);
    genvar i;
    integer a;

    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq ? i_enq_req : 0;
    wire[`WDEF(INPORT_NUM)] real_deq_vld = i_deq_req & o_can_deq;
    wire [`SDEF(DEPTH)] enq_num, real_enq_num, deq_num;
    count_one
    #(
        .WIDTH ( INPORT_NUM )
    )
    u_count_one_0(
    	.i_a   ( i_enq_req   ),
        .o_sum ( enq_num )
    );
    assign o_can_enq = enq_num < remaining;

    count_one #(
        .WIDTH  ( INPORT_NUM    )
    ) u_count_one_1 (
        .i_a    ( i_enq_vld ? real_enq_vld : 0),
        .o_sum  ( real_enq_num     )
    );
    count_one #(
        .WIDTH  ( OUTPORT_NUM   )
    ) u_count_one_2 (
        .i_a    ( real_deq_vld  ),
        .o_sum  ( deq_num      )
    );

    dtype buffer[DEPTH];
    reg[`SDEF(DEPTH)] enq_ptr[INPORT_NUM], deq_ptr[OUTPORT_NUM], count;
    reg[`SDEF(DEPTH)] arch_count, arch_deq_ptr;

    if (USE_RENAME !=0) begin : gen_if
        // DESIGN:
        // commit ont inst with rd
        // the arch_deq_ptr increment by 1

        wire [`SDEF(DEPTH)] commit_num;// the arch_read_num
        count_one
        #(
            .WIDTH ( COMMIT_WID )
        )
        u_count_one_3 (
            .i_a   ( i_commit_vld   ),
            .o_sum ( commit_num )
        );
        always_ff @( posedge clk ) begin
            if (rst==true) begin
                arch_count <= 0;
                arch_deq_ptr <= 0;
            end
            else begin
                arch_count <= arch_count - commit_num + enq_num;
                arch_deq_ptr <= (arch_deq_ptr + commit_num) < DEPTH ? (arch_deq_ptr + commit_num) : (arch_deq_ptr + commit_num - DEPTH);
            end
        end
    end

    generate
        if (USE_INIT != 0) begin : gen_init
            for(i=0;i<DEPTH;i=i+1) begin:gen_init_
                always_ff @(posedge clk) begin
                    if((rst==true) || (i_flush == true)) begin
                        buffer[i] <= init_data[i];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if ((rst == true) || (i_flush == true)) begin
            count <= 0;
            for (a = 0; a < INPORT_NUM; a = a + 1) begin
                enq_ptr[i] <= i;
            end
            for (a = 0; a < OUTPORT_NUM; a = a + 1) begin
                deq_ptr[i] <= i;
            end
        end
        else if (USE_RENAME != 0) begin
            if (i_resteer_vld) begin
                count <= arch_count;
                for (a = 0; a < INPORT_NUM; a = a + 1) begin
                    deq_ptr[a] <= arch_deq_ptr + a;
                end
            end
        end
        else begin
            // enq
            if (i_enq_vld) begin
                for (a = 0; a < INPORT_NUM; a = a + 1) begin
                    if (i_enq_req[a] == true) begin
                        buffer[enq_ptr[a]] <= i_enq_data[a];
                    end
                    if (i_enq_req[0] == true) begin
                        enq_ptr[a] <= (enq_ptr[a] + real_enq_num) < DEPTH ? (enq_ptr[a] + real_enq_num) : (enq_ptr[a] + real_enq_num - DEPTH);
                    end
                end
            end
            // deq
            for (a = 0; a < OUTPORT_NUM; a = a + 1) begin
                if (i_deq_req[0] == true) begin
                    deq_ptr[a] <= (deq_ptr[a] + deq_num) < DEPTH ? (deq_ptr[a] + deq_num) : (deq_ptr[a] + deq_num - DEPTH);
                end
            end
            count <= count + real_enq_num - deq_num;
        end
    end

    wire [`SDEF(DEPTH)] existing, remaining;
    assign existing  = count;
    assign remaining = DEPTH - count;

    generate
        for (i = 0; i < OUTPORT_NUM; i = i + 1) begin : gen_output
            assign o_can_deq[i] = i < existing;
            assign o_deq_data[i]  = buffer[deq_ptr[i]];
        end
    endgenerate


    // use for waveform debug
    wire[`SDEF(DEPTH)] AAA_count = count;
    wire[`SDEF(DEPTH)] AAA_arch_count = arch_count;

    `ASSERT(count <= DEPTH);
    `ORDER_CHECK(real_deq_vld);
    `ORDER_CHECK(real_enq_vld);
endmodule
