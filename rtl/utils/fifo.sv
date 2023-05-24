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
    parameter int USE_INIT = 0
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
    input wire [`WDEF(OUTPORT_NUM)] i_enq_req,
    output dtype o_deq_data[OUTPORT_NUM]
);
    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq ? i_enq_req : 0;
    wire[`WDEF(INPORT_NUM)] real_deq_vld = i_enq_req & o_can_deq;
    wire [`SDEF(DEPTH)] enq_num, real_enq_num, deq_num;
    count_one
    #(
        .WIDTH ( INPORT_NUM )
    )
    u_count_one(
    	.i_a   ( i_enq_req   ),
        .o_sum ( enq_num )
    );

    continuous_one #(
        .WIDTH  ( INPORT_NUM    )
    ) u_continuous_one_0 (
        .i_a    ( i_enq_vld ? real_enq_vld : 0),
        .o_sum  ( real_enq_num     )
    );
    continuous_one #(
        .WIDTH  ( OUTPORT_NUM   )
    ) u_continuous_one_1 (
        .i_a    ( real_deq_vld  ),
        .o_sum  ( deq_num      )
    );

    dtype buffer[DEPTH];
    reg [`SDEF(DEPTH)] wptr[INPORT_NUM], rptr[OUTPORT_NUM], count;

    generate
        genvar i;
        if (USE_INIT) begin : gen_init
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
            for (int i = 0; i < INPORT_NUM; i = i + 1) begin
                wptr[i] <= i;
            end
            for (int i = 0; i < OUTPORT_NUM; i = i + 1) begin
                rptr[i] <= i;
            end
        end else begin
            // enq
            if (i_enq_vld) begin
                for (int i = 0; i < INPORT_NUM; i = i + 1) begin
                    if (i_enq_req[i] == true) begin
                        buffer[wptr[i]] <= i_enq_data[i];
                    end
                    if (i_enq_req[0] == true) begin
                        wptr[i] <= wptr[i] + real_enq_num - (wptr[i] < (DEPTH-INPORT_NUM+i) ? 0 : DEPTH);
                    end
                end
            end
            // deq
            for (int i = 0; i < OUTPORT_NUM; i = i + 1) begin
                if (i_enq_req[i] == true) begin
                end
                if (i_enq_req[0] == true) begin
                    rptr[i] <= rptr[i] + deq_num - (rptr[i] < (DEPTH-OUTPORT_NUM+i) ? 0 : DEPTH);
                end
            end
            count <= count + real_enq_num - deq_num;
        end
    end

    wire [`SDEF(DEPTH)] existing, remaining;
    assign existing  = count;
    assign remaining = DEPTH - count;
    assign o_can_enq = enq_num < remaining;

    generate
        for (i = 0; i < OUTPORT_NUM; i = i + 1) begin : gen_output
            assign o_can_deq[i] = i < existing;
            assign o_deq_data[i]  = buffer[rptr[i]];
        end
    endgenerate

    `ASSERT(count <= DEPTH);
    `ORDER_CHECK(real_deq_vld);
    `ORDER_CHECK(real_enq_vld);
endmodule
