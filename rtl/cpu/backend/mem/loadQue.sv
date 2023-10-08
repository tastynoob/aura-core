`include "backend_config.svh"



typedef struct {
    logic vld;
    robIdx_t rob_idx;

    logic data_vld;
    logic finished;

    paddr_t paddr;
    logic[`WDEF(3)] load_size;
    logic[`XDEF] vaddr;// debug
} LQEntry_t;

//unsafed fifo
//ordered in out
module loadQue #(
    parameter int INPORT_NUM = 4,
    parameter int OUTPORT_NUM = 4,
    parameter int DEPTH = 32
) (
    input wire clk,
    input wire rst,
    input wire i_flush,
    // enq (from dispatch)
    output wire o_can_enq,
    input wire i_enq_vld,
    input wire [`WDEF(INPORT_NUM)] i_enq_req,
    input memDQEntry_t i_enq_data[INPORT_NUM],
    output lqIdx_t o_alloc_lqIdx[INPORT_NUM]


);
    genvar i;

    wire[`WDEF(INPORT_NUM)] real_enq_vld = o_can_enq && i_enq_vld ? i_enq_req : 0;
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
    assign o_can_enq = enq_num <= remaining;

    count_one #(
        .WIDTH  ( INPORT_NUM    )
    ) u_count_one_1 (
        .i_a    ( real_enq_vld  ),
        .o_sum  ( real_enq_num  )
    );
    count_one #(
        .WIDTH  ( OUTPORT_NUM   )
    ) u_count_one_2 (
        .i_a    ( real_deq_vld  ),
        .o_sum  ( deq_num       )
    );

    LQEntry_t buffer[DEPTH];
    reg[`WDEF($clog2(DEPTH))] enq_ptr[INPORT_NUM], deq_ptr[OUTPORT_NUM];
    reg[`WDEF($clog2(DEPTH))] arch_deq_ptr;
    reg[`SDEF(DEPTH)] count, arch_count;

    always_ff @(posedge clk) begin
        int fa;
        if ((rst == true) || (i_flush == true)) begin
            count <= 0;

            for (fa = 0; fa < INPORT_NUM; fa = fa + 1) begin
                enq_ptr[fa] <= fa;
            end
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= fa;
            end
        end
        else begin
            // enq
            for (fa = 0; fa < INPORT_NUM; fa = fa + 1) begin
                if (real_enq_vld[fa] == true) begin
                    buffer[enq_ptr[fa]] <= i_enq_data[fa];
                end

                enq_ptr[fa] <= (enq_ptr[fa] + real_enq_num) < DEPTH ? (enq_ptr[fa] + real_enq_num) : (enq_ptr[fa] + real_enq_num - DEPTH);
            end
            // deq
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= ((deq_ptr[fa] + deq_num) < DEPTH) ? (deq_ptr[fa] + deq_num) : (deq_ptr[fa] + deq_num - DEPTH);
            end
            count <= count + real_enq_num - deq_num;
        end
    end

    wire [`SDEF(DEPTH)] existing, remaining;
    assign existing  = count;
    assign remaining = DEPTH - count;

    generate
        for (i = 0; i < OUTPORT_NUM; i = i + 1) begin : gen_output
            assign o_can_deq[i] = ((i+1) <= existing);
            assign o_deq_data[i] = buffer[deq_ptr[i]];
        end
    endgenerate


    // use for waveform debug
    wire[`SDEF(DEPTH)] AAA_count = count;

    wire[`SDEF(DEPTH)] AAA_enq_num = real_enq_num;
    wire[`SDEF(DEPTH)] AAA_deq_num = deq_num;

    `ASSERT(count <= DEPTH);

    `ORDER_CHECK(real_deq_vld);

    `ORDER_CHECK(real_enq_vld);

endmodule




