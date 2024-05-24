`include "backend_define.svh"


import "DPI-C" function void storeQue_write_addr(
    uint64_t vaddr,
    uint64_t size,
    uint64_t sqIdx
);
import "DPI-C" function void storeQue_write_data(
    uint64_t data,
    uint64_t sqIdx
);


import "DPI-C" function void pmem_write(
    uint64_t paddr,
    uint64_t data
);

// load: forward | writeQue | finish |
// store:        |  s0      | writeQue, checkvio | finish

typedef struct {
    robIdx_t robIdx;
    sqIdx_t sqIdx;
    logic addr_vld;
    logic data_vld;
    logic finished;
    logic committed;  // wait for writeback to cache
    logic [`XDEF] vaddr;
    paddr_t paddr;
    logic [`WDEF(`XLEN/8)] storemask;
    logic [`WDEF(64)] data;
} SQEntry_t;

module storeQue #(
    parameter int INPORT_NUM  = 2,
    parameter int OUTPORT_NUM = `COMMIT_WIDTH,
    parameter int DEPTH       = `SQSIZE
) (
    input wire clk,
    input wire rst,
    input wire i_flush,
    // from/to storeque
    store2que_if.s if_sta2que[`STU_NUM],
    store2que_if.s if_std2que[`STU_NUM],
    // store -> load forward
    stfwd_if.s if_stfwd[`LDU_NUM],
    // storeQue -> dcache
    // store2dcache_if.m if_st2dcache[2],

    output wire [`WDEF(`STU_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[`STU_NUM],

    input wire [`SDEF(`COMMIT_WIDTH)] i_committed_stores,
    output wire [`SDEF(`COMMIT_WIDTH)] o_released_stores
);
    genvar i, j, k;

    SQEntry_t buff[DEPTH];
    SQEntry_t nxt_buff[DEPTH];
    wire [`XDEF] shifted_data[DEPTH];
    reg [`WDEF($clog2(DEPTH))] deq_ptr[OUTPORT_NUM];
    reg [`WDEF($clog2(DEPTH))] finish_ptr[`STU_NUM];
    reg [`WDEF($clog2(DEPTH))] committed_deq_ptr[OUTPORT_NUM];

    always_comb begin
        nxt_buff = buff;
        if (if_sta2que[0].vld) begin
            nxt_buff[if_sta2que[0].sqIdx.idx].addr_vld = 1;
            nxt_buff[if_sta2que[0].sqIdx.idx].vaddr = if_sta2que[0].vaddr;
            nxt_buff[if_sta2que[0].sqIdx.idx].paddr = if_sta2que[0].paddr;
            nxt_buff[if_sta2que[0].sqIdx.idx].storemask = if_sta2que[0].storemask;
            nxt_buff[if_sta2que[0].sqIdx.idx].robIdx = if_sta2que[0].robIdx;
            nxt_buff[if_sta2que[0].sqIdx.idx].sqIdx = if_sta2que[0].sqIdx;
        end
        if (if_sta2que[1].vld) begin
            nxt_buff[if_sta2que[1].sqIdx.idx].addr_vld = 1;
            nxt_buff[if_sta2que[1].sqIdx.idx].vaddr = if_sta2que[1].vaddr;
            nxt_buff[if_sta2que[1].sqIdx.idx].paddr = if_sta2que[1].paddr;
            nxt_buff[if_sta2que[1].sqIdx.idx].storemask = if_sta2que[1].storemask;
            nxt_buff[if_sta2que[1].sqIdx.idx].robIdx = if_sta2que[1].robIdx;
            nxt_buff[if_sta2que[1].sqIdx.idx].sqIdx = if_sta2que[1].sqIdx;
        end
        if (if_std2que[0].vld) begin
            nxt_buff[if_std2que[0].sqIdx.idx].data_vld = 1;
            nxt_buff[if_std2que[0].sqIdx.idx].data = if_std2que[0].data;
        end
        if (if_std2que[1].vld) begin
            nxt_buff[if_std2que[1].sqIdx.idx].data_vld = 1;
            nxt_buff[if_std2que[1].sqIdx.idx].data = if_std2que[1].data;
        end
    end

    always_ff @(posedge clk) begin
        int fa, fb;
        int finished_num;
        if (rst) begin
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= fa;
                committed_deq_ptr[fa] <= fa;
            end
            for (fa = 0; fa < `STU_NUM; fa = fa + 1) begin
                finish_ptr[fa] <= fa;
            end
            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                buff[fa].addr_vld <= 0;
                buff[fa].data_vld <= 0;
                buff[fa].finished <= 0;
                buff[fa].committed <= 0;
            end
        end
        else if (i_flush) begin
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= fa;
            end
            for (fa = 0; fa < `STU_NUM; fa = fa + 1) begin
                finish_ptr[fa] <= fa;
            end
            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                if (!buff[fa].committed) begin
                    buff[fa].addr_vld <= 0;
                    buff[fa].data_vld <= 0;
                    buff[fa].finished <= 0;
                end
            end
        end
        else begin
            if (if_sta2que[0].vld) begin
                assert (buff[if_sta2que[0].sqIdx.idx].addr_vld == 0);
                buff[if_sta2que[0].sqIdx.idx].addr_vld <= 1;
                buff[if_sta2que[0].sqIdx.idx].vaddr <= if_sta2que[0].vaddr;
                buff[if_sta2que[0].sqIdx.idx].paddr <= if_sta2que[0].paddr;
                buff[if_sta2que[0].sqIdx.idx].storemask <= if_sta2que[0].storemask;
                buff[if_sta2que[0].sqIdx.idx].robIdx <= if_sta2que[0].robIdx;
                buff[if_sta2que[0].sqIdx.idx].sqIdx <= if_sta2que[0].sqIdx;

                storeQue_write_addr(if_sta2que[0].vaddr, count_one(
                                    if_sta2que[0].storemask),
                                    if_sta2que[0].sqIdx.idx);
            end
            if (if_sta2que[1].vld) begin
                assert (buff[if_sta2que[1].sqIdx.idx].addr_vld == 0);
                buff[if_sta2que[1].sqIdx.idx].addr_vld <= 1;
                buff[if_sta2que[1].sqIdx.idx].vaddr <= if_sta2que[1].vaddr;
                buff[if_sta2que[1].sqIdx.idx].paddr <= if_sta2que[1].paddr;
                buff[if_sta2que[1].sqIdx.idx].storemask <= if_sta2que[1].storemask;
                buff[if_sta2que[1].sqIdx.idx].robIdx <= if_sta2que[1].robIdx;
                buff[if_sta2que[1].sqIdx.idx].sqIdx <= if_sta2que[1].sqIdx;

                storeQue_write_addr(if_sta2que[1].vaddr, count_one(
                                    if_sta2que[1].storemask),
                                    if_sta2que[1].sqIdx.idx);
            end
            if (if_std2que[0].vld) begin
                assert (buff[if_std2que[0].sqIdx.idx].data_vld == 0);
                buff[if_std2que[0].sqIdx.idx].data_vld <= 1;
                buff[if_std2que[0].sqIdx.idx].data <= if_std2que[0].data;

                storeQue_write_data(if_std2que[0].data,
                                    if_std2que[0].sqIdx.idx);
            end
            if (if_std2que[1].vld) begin
                assert (buff[if_std2que[1].sqIdx.idx].data_vld == 0);
                buff[if_std2que[1].sqIdx.idx].data_vld <= 1;
                buff[if_std2que[1].sqIdx.idx].data <= if_std2que[1].data;

                storeQue_write_data(if_std2que[1].data,
                                    if_std2que[1].sqIdx.idx);
            end

            // finish
            finished_num = count_one(o_fu_finished);
            for (fa = 0; fa < `STU_NUM; fa = fa + 1) begin
                if (o_fu_finished[0]) begin
                    finish_ptr[fa] <= (finish_ptr[fa] + finished_num) < DEPTH ? (finish_ptr[fa] + finished_num) : (finish_ptr[fa] + finished_num - DEPTH);
                end
            end

            if (o_fu_finished[0]) begin
                buff[finish_ptr[0]].finished <= 1;
            end
            if (o_fu_finished[1]) begin
                buff[finish_ptr[1]].finished <= 1;
            end

            // commit
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= (deq_ptr[fa] + i_committed_stores) < DEPTH ? (deq_ptr[fa] + i_committed_stores) : (deq_ptr[fa] + i_committed_stores - DEPTH);
                if (i_committed_stores > fa) begin
                    assert (buff[deq_ptr[fa]].addr_vld == 1);
                    assert (buff[deq_ptr[fa]].data_vld == 1);
                    // buff[deq_ptr[fa]].committed <= 1;
                    buff[deq_ptr[fa]].addr_vld <= 0;
                    buff[deq_ptr[fa]].data_vld <= 0;
                    // simulate write
                    for (fb = 0; fb < 8; fb = fb + 1) begin
                        if (buff[deq_ptr[fa]].storemask[fb]) begin
                            pmem_write(
                                {buff[deq_ptr[fa]].paddr[`PALEN-1:3], 3'b0} + fb,
                                (shifted_data[deq_ptr[fa]] >> (fb * 8)));
                        end
                    end
                end
            end

            // write back to cache
        end
    end

    assign o_released_stores = i_committed_stores;

    generate
        for (i = 0; i < `STU_NUM; i = i + 1) begin
            assign o_fu_finished[i] = buff[finish_ptr[i]].addr_vld && buff[finish_ptr[i]].data_vld;
            assign o_comwbInfo[i] = '{
                    default: 0,
                    rob_idx: buff[finish_ptr[i]].robIdx
                };
        end
    endgenerate

    // store->load forward

    // s0 vaddr match
    wire [`WDEF(DEPTH)] data_vlds;
    wire [`WDEF(DEPTH)] vaddr_match_vec[`LDU_NUM];
    wire [
    `WDEF(DEPTH)
    ] data_match_vec[`LDU_NUM][8];  // each byte matched with vaddr
    robIdx_t store_ages[DEPTH];
    wire [`WDEF(`LDU_NUM)] forward_write_conflict;
    wire [`WDEF($clog2(DEPTH))] entry_indexs[DEPTH];


    reg [`WDEF(`LDU_NUM)] s1_forward_write_conflict;
    reg [`WDEF(DEPTH)] s1_vaddr_match_vec[`LDU_NUM];
    wire [`WDEF(DEPTH)] s1_paddr_match_vec[`LDU_NUM];
    wire [`WDEF(8)] s1_byte_match_vec[`LDU_NUM];
    reg [`WDEF(DEPTH)] s1_data_match_vec[`LDU_NUM][8];
    reg [`WDEF(`XLEN/8)] s1_loadmask[`LDU_NUM];  // load mask for forward
    reg [`WDEF(`XLEN/8)] s1_match_and_data_rdy[`LDU_NUM];
    wire [
    `WDEF($clog2(DEPTH))
    ] s1_match_byte_entry[`LDU_NUM][8];  // each byte matched newest entry
    wire [`WDEF(8)] s1_matched_byte[`LDU_NUM][8];

    paddr_t s2_stfwd_paddr[`LDU_NUM];
    reg [`WDEF(DEPTH)] s2_paddr_match_vec[`LDU_NUM];
    reg [`WDEF(8)] s2_byte_match_vec[`LDU_NUM];
    reg s2_paddr_match[`LDU_NUM];
    reg [`WDEF(8)] s2_matched_byte[`LDU_NUM][8];
    reg s2_stfwd_req[`LDU_NUM];
    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            s1_forward_write_conflict <= 0;
            // s1_vaddr_match_vec <= 0;
            // s1_data_match_vec <= 0;
            // s1_loadmask <= {0,0};

            // s2_paddr_match_vec <= {0,0};
            // s2_byte_match_vec <= {0,0};
            s2_stfwd_req <= {0, 0};
        end
        else begin
            s1_forward_write_conflict <= forward_write_conflict;
            s1_vaddr_match_vec <= vaddr_match_vec;
            s1_data_match_vec <= data_match_vec;

            s1_loadmask[0] <= if_stfwd[0].s0_load_vec;
            s2_paddr_match[0] <= (s1_vaddr_match_vec[0] == s1_paddr_match_vec[0]) && (s1_vaddr_match_vec[0] != 0);

            s1_loadmask[1] <= if_stfwd[1].s0_load_vec;
            s2_paddr_match[1] <= (s1_vaddr_match_vec[1] == s1_paddr_match_vec[1]) && (s1_vaddr_match_vec[1] != 0);

            s2_paddr_match_vec <= s1_paddr_match_vec;
            s2_byte_match_vec <= s1_byte_match_vec;
            s2_matched_byte <= s1_matched_byte;

            s2_stfwd_paddr[0] <= if_stfwd[0].s1_paddr;
            s2_stfwd_paddr[1] <= if_stfwd[1].s1_paddr;

            s2_stfwd_req[0] <= if_stfwd[0].s1_vld;
            s2_stfwd_req[1] <= if_stfwd[1].s1_vld;
        end
    end
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin
            assign entry_indexs[i] = i;
            assign data_vlds[i] = buff[i].data_vld;
            assign store_ages[i] = buff[i].robIdx;
            for (j = 0; j < `LDU_NUM; j = j + 1) begin
                assign vaddr_match_vec[j][i] =
                    if_stfwd[j].s0_vld &&
                    nxt_buff[i].addr_vld &&
                    `OLDER_THAN(nxt_buff[i].sqIdx, if_stfwd[j].s0_sqIdx) &&
                    (nxt_buff[i].vaddr[`XLEN-1:3] == if_stfwd[j].s0_vaddr[`XLEN-1:3]);

                assign s1_paddr_match_vec[j][i] =
                    if_stfwd[j].s1_vld &&
                    s1_vaddr_match_vec[j][i] &&
                    (buff[i].paddr[`PALEN-1:3] == if_stfwd[j].s1_paddr[`PALEN-1:3]);
            end

            for (j = 0; j < 8; j = j + 1) begin
                for (k = 0; k < `LDU_NUM; k = k + 1) begin
                    assign data_match_vec[k][j][i] =
                        vaddr_match_vec[k][i] &&
                        (nxt_buff[i].storemask[j] && if_stfwd[k].s0_load_vec[j]);
                end
            end

            assign shifted_data[i] = (buff[i].data << (({3'b0, buff[i].vaddr[2:0]}) << 3));
        end
        for (i = 0; i < `LDU_NUM; i = i + 1) begin : gen_loadforward
            assign forward_write_conflict[i] =
                if_stfwd[i].s0_vld &&
                (
                (if_sta2que[0].vld && (if_stfwd[i].s0_sqIdx > if_sta2que[0].sqIdx) && (if_stfwd[i].s0_vaddr[`XLEN-1:3] == if_sta2que[0].vaddr[`XLEN-1:3])) ||
                (if_sta2que[1].vld && (if_stfwd[i].s0_sqIdx > if_sta2que[1].sqIdx) && (if_stfwd[i].s0_vaddr[`XLEN-1:3] == if_sta2que[1].vaddr[`XLEN-1:3]))
                );

            for (j = 0; j < 8; j = j + 1) begin : gen_byte
                // each byte
                newest_select #(
                    .WIDTH(DEPTH),
                    .dtype(logic [`WDEF($clog2(DEPTH))])
                ) u_newest_select (
                    .i_vld           (s1_data_match_vec[i][j]),
                    .i_rob_idx       (store_ages),
                    .i_datas         (entry_indexs),
                    .o_newest_rob_idx(),
                    .o_newest_data   (s1_match_byte_entry[i][j])
                );
                assign s1_byte_match_vec[i][j] = (|s1_data_match_vec[i][j]);
                assign s1_match_and_data_rdy[i][j] = s1_loadmask[i][j] ? (|s1_vaddr_match_vec[i]) && (buff[s1_match_byte_entry[i][j]].data_vld) : 1;
                assign s1_matched_byte[i][j] = (shifted_data[s1_match_byte_entry[i][j]][(j+1)*8-1 : j*8]);
            end
        end

        for (i = 0; i < `LDU_NUM; i = i + 1) begin
            assign if_stfwd[i].s1_vaddr_match = (|s1_vaddr_match_vec[i]);
            assign if_stfwd[i].s1_data_rdy = (&s1_match_and_data_rdy[i]);

            assign if_stfwd[i].s2_paddr_match = s2_stfwd_req[i] ? s2_paddr_match[i] : 0;
            assign if_stfwd[i].s2_match_failed = s2_stfwd_req[i] ? !s2_paddr_match[i] : 0;
            assign if_stfwd[i].s2_match_vec = (s2_stfwd_req[i] && if_stfwd[i].s2_paddr_match) ? (s2_byte_match_vec[i] >> (s2_stfwd_paddr[i][2:0])) : 0;
            assign if_stfwd[i].s2_fwd_data = ({
                s2_matched_byte[i][7],
                s2_matched_byte[i][6],
                s2_matched_byte[i][5],
                s2_matched_byte[i][4],
                s2_matched_byte[i][3],
                s2_matched_byte[i][2],
                s2_matched_byte[i][1],
                s2_matched_byte[i][0]
            } >> ({3'b0, s2_stfwd_paddr[i][2:0]} << 3));
        end
    endgenerate



endmodule
