`include "backend_define.svh"



typedef struct {
    robIdx_t robIdx;
    logic addr_vld;
    logic data_vld;
    logic committed;
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

    input wire [`WDEF($clog2(`COMMIT_WIDTH))] i_committed_stores,
    input wire [`WDEF($clog2(`COMMIT_WIDTH))] o_released_stores
);
    genvar i, j, k;


    SQEntry_t buff[DEPTH];
    reg [`WDEF($clog2(DEPTH))] deq_ptr[OUTPORT_NUM];
    reg [`WDEF($clog2(DEPTH))] committed_deq_ptr[OUTPORT_NUM];

    always_ff @(posedge clk) begin
        int fa;
        if (rst || i_flush) begin
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                deq_ptr[fa] <= fa;
                committed_deq_ptr[fa] <= fa;
            end
        end
        else begin
            if (if_sta2que[0].vld) begin
                assert (buff[if_sta2que[0].sqIdx].addr_vld == 0);
                buff[if_sta2que[0].sqIdx].addr_vld <= 1;
                buff[if_sta2que[0].sqIdx].vaddr <= if_sta2que[0].vaddr;
                buff[if_sta2que[0].sqIdx].paddr <= if_sta2que[0].paddr;
                buff[if_sta2que[0].sqIdx].storemask <= if_sta2que[0].storemask;
                buff[if_sta2que[0].sqIdx].robIdx <= if_sta2que[0].robIdx;
            end
            if (if_std2que[0].vld) begin
                assert (buff[if_std2que[0].sqIdx].data_vld == 0);
                buff[if_std2que[0].sqIdx].data <= if_std2que[0].data;
            end
            if (if_sta2que[1].vld) begin
                assert (buff[if_sta2que[1].sqIdx].addr_vld == 0);
                buff[if_sta2que[1].sqIdx].addr_vld <= 1;
                buff[if_sta2que[1].sqIdx].vaddr <= if_sta2que[1].vaddr;
                buff[if_sta2que[1].sqIdx].paddr <= if_sta2que[1].paddr;
                buff[if_sta2que[1].sqIdx].storemask <= if_sta2que[1].storemask;
                buff[if_sta2que[1].sqIdx].robIdx <= if_sta2que[1].robIdx;
            end
            if (if_std2que[1].vld) begin
                assert (buff[if_std2que[1].sqIdx].data_vld == 0);
                buff[if_std2que[1].sqIdx].data <= if_std2que[1].data;
            end



            // commit
            for (fa = 0; fa < OUTPORT_NUM; fa = fa + 1) begin
                if (i_committed_stores[fa]) begin
                    deq_ptr[fa] <= (deq_ptr[fa] + i_committed_stores) < DEPTH ? (deq_ptr[fa] + i_committed_stores) : (deq_ptr[fa] + i_committed_stores - DEPTH);
                    assert (buff[deq_ptr[fa]].addr_vld == 1);
                    buff[deq_ptr[fa]].committed <= 1;
                end
            end

            // after commit

        end
    end


    // store->load forward

    // s0 vaddr match
    wire [`WDEF(DEPTH)] data_vlds;
    wire [`WDEF(DEPTH)] vaddr_match_vec[`LDU_NUM];
    wire [`WDEF(DEPTH)] data_match_vec[`LDU_NUM][8];// each byte matched with vaddr
    robIdx_t store_ages[DEPTH];

    wire[`WDEF($clog2(DEPTH))] entry_indexs[DEPTH];

    reg [`WDEF(DEPTH)] s1_vaddr_match_vec[`LDU_NUM];
    wire [`WDEF(DEPTH)] s1_paddr_match_vec[`LDU_NUM];
    wire [`WDEF(8)] s1_byte_match_vec[`LDU_NUM];
    reg [`WDEF(DEPTH)] s1_data_match_vec[`LDU_NUM][8];
    reg[`WDEF(`XLEN/8)] s1_loadmask[`LDU_NUM]; // load mask for forward
    reg[`WDEF(`XLEN/8)] s1_match_and_data_rdy[`LDU_NUM];
    wire[`WDEF($clog2(DEPTH))] s1_match_byte_entry[`LDU_NUM][8];// each byte matched newest entry
    wire[`WDEF(8)] s1_matched_byte[`LDU_NUM][8];

    reg [`WDEF(DEPTH)] s2_paddr_match_vec[`LDU_NUM];
    reg [`WDEF(8)] s2_byte_match_vec[`LDU_NUM];
    reg s2_paddr_match[`LDU_NUM];
    reg[`WDEF(8)] s2_matched_byte[`LDU_NUM][8];
    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            // s1_vaddr_match_vec <= 0;
            // s1_data_match_vec <= 0;
            // s1_loadmask <= {0,0};

            // s2_paddr_match_vec <= {0,0};
            // s2_byte_match_vec <= {0,0};
        end
        else begin
            s1_vaddr_match_vec <= vaddr_match_vec;
            s1_data_match_vec <= data_match_vec;

            s1_loadmask[0] <= if_stfwd[0].s0_load_vec;
            s2_paddr_match[0] <= (s1_vaddr_match_vec[0] == s1_paddr_match_vec[0]);

            s1_loadmask[1] <= if_stfwd[1].s0_load_vec;
            s2_paddr_match[1] <= (s1_vaddr_match_vec[1] == s1_paddr_match_vec[1]);

            s2_paddr_match_vec <= s1_paddr_match_vec;
            s2_byte_match_vec <= s1_byte_match_vec;
            s2_matched_byte <= s1_matched_byte;
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
                    buff[i].addr_vld &&
                    (if_stfwd[j].s0_sqIdx <= i) &&
                    (buff[i].vaddr[`XLEN-1:3] == if_stfwd[j].s0_vaddr[`XLEN-1:3]);

                assign s1_paddr_match_vec[j][i] =
                    if_stfwd[j].s1_vld &&
                    s1_vaddr_match_vec[j][i] &&
                    (buff[i].paddr[`PALEN-1:3] == if_stfwd[j].s1_paddr[`PALEN-1:3]);
            end

            for (j = 0; j < 8; j = j + 1) begin
                for (k = 0; k < `LDU_NUM; k = k + 1) begin
                    assign data_match_vec[k][j][i] =
                        (buff[i].vaddr[`XLEN-1:3] == if_stfwd[k].s0_vaddr[`XLEN-1:3]) &&
                        (buff[i].storemask[j] == if_stfwd[k].s0_load_vec[j]);
                end
            end
        end
        for (i = 0; i < `LDU_NUM; i = i + 1) begin : gen_loadforward
            for (j = 0; j < 8; j = j + 1) begin : gen_byte
                // each byte
                newest_select #(
                    .WIDTH(DEPTH),
                    .dtype(logic[`WDEF($clog2(DEPTH))])
                ) u_newest_select (
                    .i_vld           (s1_data_match_vec[i][j]),
                    .i_rob_idx       (store_ages),
                    .i_datas         (entry_indexs),
                    .o_newest_rob_idx( ),
                    .o_newest_data   (s1_match_byte_entry[i][j])
                );
                assign s1_byte_match_vec[i][j] = (|s1_data_match_vec[i][j]);
                assign s1_match_and_data_rdy[i][j] = s1_loadmask[i][j] ? (|s1_vaddr_match_vec[i]) && (buff[s1_match_byte_entry[i][j]].data_vld) : 1;
                assign s1_matched_byte[i][j] = buff[s1_match_byte_entry[i][j]].data[(j+1)*8 - 1 : j*8];
            end
        end

        for (i = 0; i < `LDU_NUM; i = i + 1) begin
            assign if_stfwd[i].s1_vaddr_match = |s1_vaddr_match_vec[i];
            assign if_stfwd[i].s1_data_rdy = |s1_match_and_data_rdy[i];

            assign if_stfwd[i].s2_paddr_match = s2_paddr_match[i];
            assign if_stfwd[i].s2_match_failed = !s2_paddr_match[i];
            assign if_stfwd[i].s2_match_vec = s2_byte_match_vec[i];
            assign if_stfwd[i].s2_fwd_data = {
                s2_matched_byte[i][7],
                s2_matched_byte[i][6],
                s2_matched_byte[i][5],
                s2_matched_byte[i][4],
                s2_matched_byte[i][3],
                s2_matched_byte[i][2],
                s2_matched_byte[i][1],
                s2_matched_byte[i][0]
            };
        end
    endgenerate



endmodule
