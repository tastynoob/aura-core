`include "backend_define.svh"

typedef struct {
    logic vld;
    sqIdx_t sqIdx;
    logic [`XDEF] vaddr;
    paddr_t paddr;
    logic [`WDEF(`XLEN/8)] loadmask;  // 8 byte aligned

    robIdx_t robIdx;
    logic [`XDEF] pc;
} LQEntry_t;

// load pipeline:
// use virtual index -> read meta sram -> tag compare -> read data sram -> return data
// use virtual tag   ->  TLB translate -^
module loadQue #(
    parameter int INPORT_NUM  = 2,
    parameter int OUTPORT_NUM = `COMMIT_WIDTH,
    parameter int DEPTH       = `LQSIZE
) (
    input wire clk,
    input wire rst,
    input wire i_flush,
    // from/to loadque
    load2que_if.s if_load2que[`LDU_NUM],
    // store execute, violation check
    staviocheck_if.s if_viocheck[`STU_NUM],

    input wire [`WDEF($clog2(`COMMIT_WIDTH))] i_committed_loads
);
    genvar i, j;

    LQEntry_t buff[DEPTH];
    reg [`WDEF($clog2(DEPTH))] deq_ptr[OUTPORT_NUM];

    always_ff @(posedge clk) begin
        int fa;
        if (rst || i_flush) begin
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= fa;
            end
            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                buff[fa].vld <= 0;
            end
        end
        else begin
            if (if_load2que[0].vld) begin
                assert (buff[if_load2que[0].lqIdx].vld == 0);
                buff[if_load2que[0].lqIdx].vld <= 1;
                buff[if_load2que[0].lqIdx].sqIdx <= if_load2que[0].sqIdx;
                buff[if_load2que[0].lqIdx].vaddr <= if_load2que[0].vaddr;
                buff[if_load2que[0].lqIdx].paddr <= if_load2que[0].paddr;
                buff[if_load2que[0].lqIdx].loadmask <= if_load2que[0].loadmask;

                buff[if_load2que[0].lqIdx].robIdx <= if_load2que[0].robIdx;
                buff[if_load2que[0].lqIdx].pc <= if_load2que[0].pc;
            end
            if (if_load2que[1].vld) begin
                assert (buff[if_load2que[1].lqIdx].vld == 0);
                buff[if_load2que[1].lqIdx].vld <= 1;
                buff[if_load2que[1].lqIdx].sqIdx <= if_load2que[1].sqIdx;
                buff[if_load2que[1].lqIdx].vaddr <= if_load2que[1].vaddr;
                buff[if_load2que[1].lqIdx].paddr <= if_load2que[1].paddr;
                buff[if_load2que[1].lqIdx].loadmask <= if_load2que[1].loadmask;

                buff[if_load2que[1].lqIdx].robIdx <= if_load2que[1].robIdx;
                buff[if_load2que[1].lqIdx].pc <= if_load2que[1].pc;
            end


            // commit
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= (deq_ptr[fa] + i_committed_loads) < DEPTH ? (deq_ptr[fa] + i_committed_loads) : (deq_ptr[fa] + i_committed_loads - DEPTH);
                if (i_committed_loads > 0) begin
                    assert (buff[deq_ptr[fa]].vld == 1);
                    buff[deq_ptr[fa]].vld <= 0;
                end
            end
        end
    end

    // check violation
    wire [`WDEF(DEPTH)] violation_vec[`STU_NUM];
    generate
        for (i = 0; i < `STU_NUM; i = i + 1) begin
            for (j = 0; j < DEPTH; j = j + 1) begin
                assign violation_vec[i][j] = buff[j].vld && if_viocheck[i].vld &&
                    (buff[j].sqIdx <= if_viocheck[i].sqIdx) &&
                    (buff[j].paddr[`PALEN-1 : 3] == if_viocheck[i].paddr[`PALEN-1:3]) &&
                    (buff[j].loadmask & if_viocheck[i].mask != 0);
            end
        end
    endgenerate

    // get oldest violation
    robIdx_t vio_ages[DEPTH];
    wire [`WDEF($clog2(DEPTH))] entry_index[DEPTH];
    wire [`WDEF($clog2(DEPTH))] oldestvio_entry_index[`STU_NUM];
    LQEntry_t oldestvio_entry[`STU_NUM];
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin
            assign vio_ages[i] = buff[i].robIdx;
            assign entry_index[i] = i;
        end
        for (i = 0; i < `STU_NUM; i = i + 1) begin:gen_viocheck
            oldest_select #(
                .WIDTH(DEPTH),
                .dtype(logic[`WDEF($clog2(DEPTH))])
            ) u_oldest_select (
                .i_vld           (violation_vec[i]),
                .i_rob_idx       (vio_ages),
                .i_datas         (entry_index),
                .o_oldest_rob_idx(),
                .o_oldest_data   (oldestvio_entry_index[i])
            );
            assign oldestvio_entry[i] = buff[oldestvio_entry_index[i]];
        end
    endgenerate


    reg violation_vec_or[`STU_NUM];
    LQEntry_t s2_oldestvio_entry[`STU_NUM];
    always_ff @(posedge clk) begin
        int fa;
        if (rst || i_flush) begin
            for (fa = 0; fa < `STU_NUM; fa = fa + 1) begin
                violation_vec_or[fa] <= 0;
            end
        end
        else begin
            for (fa = 0; fa < `STU_NUM; fa = fa + 1) begin
                violation_vec_or[fa] <= |violation_vec[fa];
                s2_oldestvio_entry[fa] <= oldestvio_entry[fa];
            end
        end
    end


    generate
        for (i = 0; i < `STU_NUM; i = i + 1) begin
            assign if_viocheck[i].vio = violation_vec_or[i];
            assign if_viocheck[i].vioload_robIdx = s2_oldestvio_entry[i].robIdx;
            assign if_viocheck[i].vioload_pc = s2_oldestvio_entry[i].pc;
        end
    endgenerate



endmodule




