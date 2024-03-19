`include "backend_config.svh"

typedef struct {
    logic vld;
    logic finished;// load is writebacked, can be committed
    // pointer
    robIdx_t rob_idx;
    sqIdx_t sq_idx;
    iprIdx_t iprd_idx;

    logic vaddr_vld;
    logic paddr_vld;
    logic[`XDEF] vaddr;
    paddr_t paddr;
    logic[`WDEF(`XDEF/8)] load_vec;// maybe: ((1 << [1, 2, 4, 8]) - 1) << addr[2:0]

    logic cachemiss;// cache miss, need listen for cache refill
    logic has_except; // exception, such as addr misaligned, loadfault, pagefault
    rv_trap_t::exception except;

    logic[`WDEF(`XDEF/8)] vld_vec;// mask which byte was vld
    logic[`XDEF] val; // if load is miss, val will wait for refill data or store forward
} LQEntry_t;

// load pipeline:
// use virtual index -> read meta sram -> tag compare -> read data sram -> return data
// use virtual tag   ->  TLB translate -^
module loadQue #(
    parameter int INPORT_NUM = 4,
    parameter int OUTPORT_NUM = 4,
    parameter int DEPTH = `LQSIZE
) (
    input wire clk,
    input wire rst,
    input wire i_flush,
    // enq (from dispatch)
    output wire o_can_enq,
    input wire i_enq_vld,
    input wire [`WDEF(INPORT_NUM)] i_enq_req,
    input microOp_t i_enq_data[INPORT_NUM],
    output lqIdx_t o_alloc_lqIdx[INPORT_NUM],

    // loadQue should listen to loadpipe
    // loadIQ issue s0

    // from/to loadque
    load2que_if.s if_load2que[`LDU_NUM],

    sta2ldque_if.s if_sta2ldque[`STU_NUM]



);
    genvar i,j;

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

    LQEntry_t buff[DEPTH];
    reg[`WDEF(INPORT_NUM)] enq_ptr_flipped;
    reg[`WDEF($clog2(DEPTH))] enq_ptr[INPORT_NUM], deq_ptr[OUTPORT_NUM];
    reg[`SDEF(DEPTH)] count;

    always_ff @(posedge clk) begin
        int fa;
        if ((rst == true) || (i_flush == true)) begin
            count <= 0;
            enq_ptr_flipped <= 0;
            for (fa = 0; fa < INPORT_NUM; fa = fa + 1) begin
                enq_ptr[fa] <= fa;
            end
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= fa;
            end
        end
        else begin
            // enq
            count <= count + real_enq_num - deq_num;
            for (fa = 0; fa < INPORT_NUM; fa = fa + 1) begin
                if (real_enq_vld[fa] == true) begin
                    buff[enq_ptr[fa]].vld <= 1;
                    buff[enq_ptr[fa]].finished <= 0;
                    buff[enq_ptr[fa]].rob_idx <= 0;
                    buff[enq_ptr[fa]].load_size <= 0;
                    buff[enq_ptr[fa]].iprd_idx <= 0;
                    buff[enq_ptr[fa]].addr_vld <= 0;
                    buff[enq_ptr[fa]].load_vec <= 0;
                    // reset status
                    buff[enq_ptr[fa]].miss <= 0;
                    buff[enq_ptr[fa]].has_except <= 0;
                    buff[enq_ptr[fa]].vld_vec <= 0;
                end

                enq_ptr[fa] <= (enq_ptr[fa] + real_enq_num) < DEPTH ? (enq_ptr[fa] + real_enq_num) : (enq_ptr[fa] + real_enq_num - DEPTH);
                if ((enq_ptr[fa] + real_enq_num) < DEPTH) begin
                end
                else begin
                    enq_ptr_flipped[fa] <= ~enq_ptr_flipped[fa];
                end
            end
            // commit

            // update status


            for (fa = 0; fa < `LDU_NUM; fa=fa+1) begin
                if (if_load2que[fa].s0_vld) begin
                    buff[if_load2que[fa].s0_lqIdx.idx].vaddr_vld <= 1;
                    buff[if_load2que[fa].s0_lqIdx.idx].vaddr <= if_load2que[fa].s0_vaddr;
                    buff[if_load2que[fa].s0_lqIdx.idx].load_vec <= if_load2que[fa].s0_load_vec;
                end

                if (if_load2que[fa].s1_vld) begin
                    buff[if_load2que[fa].s0_lqIdx.idx].paddr_vld <= 0;
                    
                end
            end
        end
    end

    generate
        for (i=0;i<INPORT_NUM;i=i+1) begin
            assign o_alloc_lqIdx[i] = '{
                flipped: enq_ptr_flipped[i],
                idx : enq_ptr[i]
            };
        end
    endgenerate


    // check violation

    wire[`WDEF(DEPTH)] violation_vec[`STU_NUM];

    generate
        for (i=0;i<`STU_NUM;i=i+1) begin
            for (j=0;j<DEPTH;j=j+1) begin
                assign violation_vec[i][j] = buff[j].vld && buff[j].addr_vld && if_sta2ldque[i].s0_vld &&
                    (buff[j].sq_idx >= if_sta2ldque[i].s0_sqIdx) &&
                    (buff[j].vaddr[`XLEN-1 : 3] == if_sta2ldque[i].s0_sta_vaddr[`XLEN-1:3]) &&
                    (buff[j].load_vec & if_sta2ldque[i].s0_store_vec != 0);
            end
        end
    endgenerate


    LQEntry_t oldest_buff;
    always_comb begin
        int ca;
        for (ca=0;ca<DEPTH;ca=ca+1) begin
            
        end
    end

endmodule




