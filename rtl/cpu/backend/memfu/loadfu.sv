
`include "backend_define.svh"

// replay at s1:
// tlb miss
// cache miss and forward unmatch
// bank conflict

// replay at s2:
// cache miss and forward match unfully
// permission denied


// if cachemiss, write the store forward data to loadque

// s0: calculate vaddr, send vaddr to tlb and tag sram
// s1: get paddr, send vaddr to data sram, tag compare, permission check
// s2: get dcache data, select data from dcache and forward info
// s3: output


module loadfu (
    input wire clk,
    input wire rst,

    output wire o_stall,
    input wire i_vld,
    input exeInfo_t i_fuInfo,

    // from/to loadque
    load2que_if.m if_load2que,
    // from/to storeque/sbuffer
    stfwd_if.m if_stfwd,
    // from/to dcache
    load2dcache_if.m if_load2cache,

    // writeback to regfile
    input wire i_wb_stall,
    output wire o_fu_finished,
    output comwbInfo_t o_comwbInfo,

    output wire o_has_except,
    output exceptwbInfo_t o_exceptwbInfo
);

    reg s0_vld;
    wire s0_continue;
    exeInfo_t s0_fuInfo;

    always_ff @( posedge clk ) begin
        if (rst) begin
            s0_vld <= 0;
        end
        else if(s0_continue) begin
            s0_vld <= i_vld;
            s0_fuInfo <= i_fuInfo;
        end
    end
    wire[`WDEF(`XLEN/8)] s0_load_vec;
    wire[`WDEF($clog2(`CACHELINE_SIZE))] s0_load_size;
    wire[`XDEF] s0_vaddr;
    wire load_misaligned;
    assign s0_vaddr = s0_fuInfo.srcs[0] + s0_fuInfo.srcs[1];
    assign s0_load_vec =
    ((s0_fuInfo.micOp == MicOp_t::lb) || (s0_fuInfo.micOp == MicOp_t::lbu)) ? 8'b0000_0001 :
    ((s0_fuInfo.micOp == MicOp_t::lh) || (s0_fuInfo.micOp == MicOp_t::lhu)) ? 8'b0000_0011 :
    ((s0_fuInfo.micOp == MicOp_t::lw) || (s0_fuInfo.micOp == MicOp_t::lwu)) ? 8'b0000_1111 :
    8'b1111_1111;

    assign s0_load_size =
    ((s0_fuInfo.micOp == MicOp_t::lb) || (s0_fuInfo.micOp == MicOp_t::lbu)) ? 1 :
    ((s0_fuInfo.micOp == MicOp_t::lh) || (s0_fuInfo.micOp == MicOp_t::lhu)) ? 2 :
    ((s0_fuInfo.micOp == MicOp_t::lw) || (s0_fuInfo.micOp == MicOp_t::lwu)) ? 4 :
    8 ;

    assign load_misaligned = (s0_vaddr[3:0] & (s0_load_size - 1)) != 0;

    /********************/
    // s0: send vaddr to tlb
    assign if_load2cache.s0_req = s0_vld;
    assign if_load2cache.s0_lqIdx = s0_fuInfo.lq_idx;
    assign if_load2cache.s0_vaddr = s0_vaddr;// fully addr

    assign s0_continue = if_load2cache.s0_gnt;
    assign o_stall = !if_load2cache.s0_gnt;

    // notify loadQue
    assign if_load2que.s0_lqIdx = s0_fuInfo.lq_idx;
    assign if_load2que.s0_vld = s0_vld && s0_continue;
    assign if_load2que.s0_vaddr = s0_vaddr;
    assign if_load2que.s0_load_vec = s0_load_vec;

    // notify storeQue/storeBuffer
    assign if_stfwd.s0_vld = s0_vld;
    assign if_stfwd.s0_lqIdx = s0_fuInfo.lq_idx;
    assign if_stfwd.s0_sqIdx = s0_fuInfo.sq_idx;
    assign if_stfwd.s0_vaddr = s0_vaddr;
    assign if_stfwd.s0_load_vec = s0_load_vec;

    /********************/
    // s1: get paddr
    // except check
    exeInfo_t s1_fuInfo;
    reg[`WDEF(`XLEN/8)] s1_load_vec;
    reg s1_vld;
    wire s1_cacherdy;

    wire s1_replay;
    wire s1_continue;
    wire s1_conflict;
    wire s1_miss;
    wire s1_pagefault;
    wire s1_illegaAddr;
    wire s1_mmio;
    wire s1_stfwd_data_rdy;
    reg s1_misagained;
    paddr_t s1_paddr;
    always_ff @( posedge clk ) begin
        if (rst) begin
            s1_vld <= 0;
        end
        else begin
            s1_fuInfo <= s0_fuInfo;
            s1_load_vec <= s0_load_vec;
            s1_vld <= s0_vld;
            s1_misagained <= load_misaligned;
        end
    end

    assign if_load2cache.s1_req = s1_vld;

    assign s1_cacherdy = if_load2cache.s1_rdy;
    assign s1_conflict = if_load2cache.s1_cft;
    assign s1_miss = if_load2cache.s1_miss;
    assign s1_pagefault = if_load2cache.s1_pagefault;
    assign s1_illegaAddr = if_load2cache.s1_illegaAddr;
    assign s1_mmio = if_load2cache.s1_mmio;
    assign s1_paddr = if_load2cache.s1_paddr;
    assign s1_stfwd_data_rdy = if_stfwd.s1_vaddr_match ? if_stfwd.s1_data_rdy : 1;// if not exist match, default true
    assign s1_replay = s1_vld && s1_conflict;
    // actually specwake no need to careabout load except
    assign s1_specwake = s1_vld && s1_stfwd_data_rdy && !(s1_conflict || s1_miss || s1_mmio || s1_pagefault || s1_illegaAddr || s1_misagained);
    assign s1_continue = s1_vld && !s1_replay;

    // if s0 cache was gnt
    // s1 must access for this request
    `ASSERT(s1_vld ? s1_cacherdy : 1);

    // notify loadQue
    assign if_load2que.s1_lqIdx = s1_fuInfo.lq_idx;
    assign if_load2que.s1_tlbmiss = !s1_tlbhit;

    // notify storeque
    assign if_stfwd.s1_vld = s1_vld;
    assign if_stfwd.s1_lqIdx = s1_fuInfo.lq_idx;
    assign if_stfwd.s1_sqIdx = s1_fuInfo.sq_idx;
    assign if_stfwd.s1_paddr = s1_paddr;

    // if cache miss, load pipe should notify loadQue

    /********************/
    // s2
    // get the dcache data
    // get the forward data
    // if cachemiss, write the forward data to loadque
    exeInfo_t s2_fuInfo;
    reg s2_vld;
    reg s2_cachemiss;
    vaddr_t s2_vaddr;
    wire s2_need_squash;
    lqIdx_t s2_lqIdx;
    always_ff @( posedge clk ) begin
        if (rst) begin
            s2_vld <= 0;
        end
        else if(s1_continue) begin
            s2_fuInfo <= s1_fuInfo;
            s2_vld <= s1_vld;
            s2_lqIdx <= s1_fuInfo.lq_idx;
            s2_cachemiss <= s1_vld && (!s1_cachehit);
        end
        else begin
            s2_vld <= 0;
        end
    end

    wire[`WDEF(`CACHELINE_SIZE*8)] s2_cacheline;
    wire[`WDEF(8)] s2_split8[`CACHELINE_SIZE];
    wire[`WDEF(16)] s2_split16[`CACHELINE_SIZE/2];
    wire[`WDEF(32)] s2_split32[`CACHELINE_SIZE/4];
    wire[`WDEF(64)] s2_split64[`CACHELINE_SIZE/8];
    wire[`WDEF(64)] s2_loadData;
    assign s2_cacheline = if_load2cache.s2_data;
    generate
        for (i=0; i<`CACHELINE_SIZE; i=i+1) begin
            assign s2_split8[i] = s2_cacheline[(i+1)*8 - 1: i*8];
        end
        for (i=0; i<`CACHELINE_SIZE/2; i=i+1) begin
            assign s2_split16[i] = s2_cacheline[(i+1)*16 - 1: i*16];
        end
        for (i=0; i<`CACHELINE_SIZE/4; i=i+1) begin
            assign s2_split32[i] = s2_cacheline[(i+1)*32 - 1: i*32];
        end
        for (i=0; i<`CACHELINE_SIZE/8; i=i+1) begin
            assign s2_split64[i] = s2_cacheline[(i+1)*64 - 1: i*64];
        end
    endgenerate
    wire[`WDEF(8)] s2_load8 = s2_split8[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:0]];
    wire[`WDEF(16)] s2_load16 = s2_split16[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:1]];
    wire[`WDEF(32)] s2_load32 = s2_split16[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:2]];
    wire[`WDEF(64)] s2_load64 = s2_split16[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:4]];
    // signed extension in s3
    assign s2_loadData =
    ((s2_fuInfo.micOp == MicOp_t::lb) || (s2_fuInfo.micOp == MicOp_t::lbu)) ? {56'd0, s2_load8} :
    ((s2_fuInfo.micOp == MicOp_t::lh) || (s2_fuInfo.micOp == MicOp_t::lhu)) ? {40'd0, s2_load16} :
    ((s2_fuInfo.micOp == MicOp_t::lw) || (s2_fuInfo.micOp == MicOp_t::lwu)) ? {32'd0, s2_load32} :
    s2_load64;

    // notify loadQue, writeback forward data if cachemiss

    assign if_load2que.s2_lqIdx = s2_fuInfo.lq_idx;
    assign if_load2que.s2_finished = 0;
    assign if_load2que.s2_except = 0;
    assign if_load2que.s2_fwd = if_stfwd.s2_match && (!if_stfwd.s2_data_nrdy);
    assign if_load2que.s2_match_vec = if_stfwd.s2_match_vec;
    assign if_load2que.s2_fwd_data = if_stfwd.s2_fwd_data;

    assign s2_need_squash = if_stfwd.s2_match_failed;

    // merge data
    wire[`XDEF] merged_data;
    generate
        for (i=0; i<`XLEN/8; i=i+1) begin
            assign merged_data[(i+1)*8-1 : i*8] =
                if_stfwd.s2_match_vec[i] ? if_stfwd.s2_fwd_data[(i+1)*8-1 : i*8] : s2_loadData[(i+1)*8-1 : i*8];
        end
    endgenerate
    // sext data
    wire[`XDEF] sext_data;
    assign sext_data =
        s2_fuInfo.micOp == MicOp_t::lb ? {{56{merged_data[7]}}, merged_data[7:0]} :
        s2_fuInfo.micOp == MicOp_t::lh ? {{48{merged_data[15]}}, merged_data[15:0]} :
        s2_fuInfo.micOp == MicOp_t::lw ? {{32{merged_data[31]}}, merged_data[31:0]} :
        merged_data;

    /********************/
    // s3
    // output
    reg load_except;
    reg load_finished;
    comwbInfo_t commwbInfo;
    exceptwbInfo_t exceptwbInfo;
    always_ff @( posedge clk ) begin
        if (rst) begin
            load_finished <= 0;
        end
        else begin
            if (s1_pagefault || s1_illegaAddr || s1_misagained) begin
                load_except <= 1;
                // early finish due to exception
                exceptwbInfo <= '{
                    rob_idx : s1_fuInfo.rob_idx,
                    except_type : rv_trap_t::loadMisaligneded
                };
            end
            else begin
                load_except <= 0;
            end

            if (s2_vld) begin
                load_finished <= 0;
                commwbInfo <= '{
                    rob_idx : s2_fuInfo.rob_idx,
                    irob_idx : s2_fuInfo.irob_idx,
                    use_imm : s2_fuInfo.use_imm,
                    rd_wen : s2_fuInfo.rd_wen,
                    iprd_idx : s2_fuInfo.iprd_idx,
                    result : sext_data
                };
            end
        end

    end

    assign o_fu_finished = load_finished;



endmodule



