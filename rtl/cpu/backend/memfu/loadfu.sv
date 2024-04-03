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

    output wire o_issue_success,
    output wire o_issue_replay,
    output iqIdx_t o_feedback_iqIdx,

    // from/to loadque
    load2que_if.m if_load2que,
    // from/to storeque/sbuffer
    stfwd_if.m if_stfwd,
    // from/to dcache
    load2dcache_if.m if_load2cache,

    output wire o_exp_swk_vld,
    output iprIdx_t o_exp_swk_iprd,

    // writeback to regfile
    input wire i_wb_stall,
    output wire o_fu_finished,
    output comwbInfo_t o_comwbInfo,

    output wire o_has_except,
    output exceptwbInfo_t o_exceptwbInfo
);
    assign o_exp_swk_vld = 0;

    genvar i;

    reg s0_vld;
    exeInfo_t s0_fuInfo;

    always_ff @(posedge clk) begin
        if (rst) begin
            s0_vld <= 0;
        end
        else begin
            s0_vld <= i_vld;
            s0_fuInfo <= i_fuInfo;
        end
    end
    wire [`XDEF] s0_vaddr;
    assign s0_vaddr = s0_fuInfo.srcs[0] + s0_fuInfo.srcs[1];

    wire [`WDEF(`XLEN/8)] s0_load_vec;
    wire [`WDEF($clog2(8))] s0_load_size;
    wire load_misaligned;
    assign s0_load_vec =
    ((s0_fuInfo.micOp == MicOp_t::lb) || (s0_fuInfo.micOp == MicOp_t::lbu)) ? (8'b0000_0001 << s0_vaddr[2:0]) :
    ((s0_fuInfo.micOp == MicOp_t::lh) || (s0_fuInfo.micOp == MicOp_t::lhu)) ? (8'b0000_0011 << s0_vaddr[2:0]) :
    ((s0_fuInfo.micOp == MicOp_t::lw) || (s0_fuInfo.micOp == MicOp_t::lwu)) ? (8'b0000_1111 << s0_vaddr[2:0]) :
    8'b1111_1111;

    assign s0_load_size =
    ((s0_fuInfo.micOp == MicOp_t::lb) || (s0_fuInfo.micOp == MicOp_t::lbu)) ? 1 :
    ((s0_fuInfo.micOp == MicOp_t::lh) || (s0_fuInfo.micOp == MicOp_t::lhu)) ? 2 :
    ((s0_fuInfo.micOp == MicOp_t::lw) || (s0_fuInfo.micOp == MicOp_t::lwu)) ? 4 :
    8 ;

    assign load_misaligned = (s0_vaddr[2:0] & (s0_load_size - 1)) != 0;

    /********************/
    assign o_stall = 0;

    // s0: send vaddr to tlb
    assign if_load2cache.s0_req = s0_vld && !load_misaligned;
    assign if_load2cache.s0_lqIdx = s0_fuInfo.lqIdx;
    assign if_load2cache.s0_vaddr = s0_vaddr;  // fully addr

    // notify storeQue/storeBuffer
    assign if_stfwd.s0_vld = s0_vld && !load_misaligned;
    assign if_stfwd.s0_lqIdx = s0_fuInfo.lqIdx;
    assign if_stfwd.s0_sqIdx = s0_fuInfo.sqIdx;
    assign if_stfwd.s0_vaddr = s0_vaddr;
    assign if_stfwd.s0_load_vec = s0_load_vec;

    /********************/
    // s1: get paddr
    // except check
    reg s1_vld;
    exeInfo_t s1_fuInfo;
    reg [`XDEF] s1_vaddr;
    reg [`WDEF(`XLEN/8)] s1_load_vec;
    reg s1_misaligned;

    wire s1_cacherdy;
    wire s1_conflict;
    wire s1_miss;
    wire s1_pagefault;
    wire s1_illegaAddr;
    wire s1_mmio;
    wire s1_stfwd_notRdy;
    paddr_t s1_paddr;

    wire s1_replay;
    wire s1_fault;
    rv_trap_t::exception s1_ldexcept;
    always_ff @(posedge clk) begin
        if (rst) begin
            s1_vld <= 0;
        end
        else begin
            s1_vld <= s0_vld;
            s1_fuInfo <= s0_fuInfo;
            s1_vaddr <= s0_vaddr;
            s1_load_vec <= s0_load_vec;
            s1_misaligned <= load_misaligned;
        end
    end

    // if s0 misaligned, do not access memory
    assign if_load2cache.s1_req = s1_vld && !s1_misaligned;
    // get mmu check info
    assign s1_cacherdy = if_load2cache.s1_rdy;
    assign s1_conflict = if_load2cache.s1_cft;
    assign s1_miss = if_load2cache.s1_miss;
    assign s1_pagefault = if_load2cache.s1_pagefault;
    assign s1_illegaAddr = if_load2cache.s1_illegaAddr;
    assign s1_mmio = if_load2cache.s1_mmio;
    assign s1_paddr = if_load2cache.s1_paddr;

    // get loadforward checko info
    assign s1_stfwd_notRdy = if_stfwd.s1_vaddr_match ? !if_stfwd.s1_data_rdy : 0;  // if not exist match, default true

    // replay if cache miss or conflict or ismmio or forward fail
    assign s1_replay = s1_conflict || s1_miss || s1_mmio || s1_stfwd_notRdy;
    // fault
    assign s1_fault = s1_misaligned || s1_pagefault || s1_illegaAddr;
    assign s1_ldexcept =
        s1_misaligned ? rv_trap_t::loadMisaligned :
        s1_pagefault ? rv_trap_t::loadPageFault :
        s1_illegaAddr ? rv_trap_t::loadFault : rv_trap_t::loadFault;

    // if s0 cache was gnt
    // s1 must access for this request
    `ASSERT(s1_vld ? s1_cacherdy : 1);

    // notify storeque
    assign if_stfwd.s1_vld = s1_vld && !(s1_replay || s1_fault);
    assign if_stfwd.s1_paddr = s1_paddr;

    assign o_issue_success = s1_vld && !(s1_replay);
    assign o_issue_replay = s1_vld && s1_replay;
    assign o_feedback_iqIdx = s1_fuInfo.iqIdx;

    /********************/
    // s2
    // get the dcache data
    // get the forward data
    reg s2_vld;
    logic [`XDEF] s2_vaddr;
    exeInfo_t s2_fuInfo;
    paddr_t s2_paddr;
    wire s2_need_squash;
    always_ff @(posedge clk) begin
        if (rst) begin
            s2_vld <= 0;
        end
        else begin
            s2_vld <= s1_vld && !(s1_replay || s1_fault);
            s2_vaddr <= s1_vaddr;
            s2_fuInfo <= s1_fuInfo;
            s2_paddr <= s1_paddr;
        end
    end
    // low provability event
    assign s2_need_squash = if_stfwd.s2_match_failed;

    wire [`WDEF(`CACHELINE_SIZE*8)] s2_cacheline;
    wire [`WDEF(8)] s2_split8[`CACHELINE_SIZE];
    wire [`WDEF(16)] s2_split16[`CACHELINE_SIZE/2];
    wire [`WDEF(32)] s2_split32[`CACHELINE_SIZE/4];
    wire [`WDEF(64)] s2_split64[`CACHELINE_SIZE/8];
    wire [`WDEF(64)] s2_loadData;
    assign s2_cacheline = if_load2cache.s2_data;
    generate
        for (i = 0; i < `CACHELINE_SIZE; i = i + 1) begin
            assign s2_split8[i] = s2_cacheline[(i+1)*8-1:i*8];
        end
        for (i = 0; i < `CACHELINE_SIZE / 2; i = i + 1) begin
            assign s2_split16[i] = s2_cacheline[(i+1)*16-1:i*16];
        end
        for (i = 0; i < `CACHELINE_SIZE / 4; i = i + 1) begin
            assign s2_split32[i] = s2_cacheline[(i+1)*32-1:i*32];
        end
        for (i = 0; i < `CACHELINE_SIZE / 8; i = i + 1) begin
            assign s2_split64[i] = s2_cacheline[(i+1)*64-1:i*64];
        end
    endgenerate
    wire [`WDEF(8)] s2_load8 = s2_split8[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:0]];
    wire [`WDEF(16)] s2_load16 = s2_split16[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:1]];
    wire [`WDEF(32)] s2_load32 = s2_split32[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:2]];
    wire [`WDEF(64)] s2_load64 = s2_split64[s2_vaddr[$clog2(`CACHELINE_SIZE)-1:3]];
    // signed extension in s3
    assign s2_loadData =
    ((s2_fuInfo.micOp == MicOp_t::lb) || (s2_fuInfo.micOp == MicOp_t::lbu)) ? {56'd0, s2_load8} :
    ((s2_fuInfo.micOp == MicOp_t::lh) || (s2_fuInfo.micOp == MicOp_t::lhu)) ? {40'd0, s2_load16} :
    ((s2_fuInfo.micOp == MicOp_t::lw) || (s2_fuInfo.micOp == MicOp_t::lwu)) ? {32'd0, s2_load32} :
    s2_load64;

    // notify loadQue
    assign if_load2que.vld = s2_vld;
    assign if_load2que.lqIdx = s2_fuInfo.lqIdx;
    assign if_load2que.vaddr = s2_vaddr;
    assign if_load2que.paddr = s2_paddr;
    assign if_load2que.loadmask = 0;

    // merge data
    wire [`XDEF] merged_data;
    generate
        for (i = 0; i < `XLEN / 8; i = i + 1) begin
            assign merged_data[(i+1)*8-1 : i*8] =
                if_stfwd.s2_match_vec[i] ? if_stfwd.s2_fwd_data[(i+1)*8-1 : i*8] : s2_loadData[(i+1)*8-1 : i*8];
        end
    endgenerate
    // sext data
    wire [`XDEF] sext_data;
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
    always_ff @(posedge clk) begin
        if (rst) begin
            load_except <= 0;
            load_finished <= 0;
        end
        else begin
            load_except <= s1_vld && s1_fault;
            exceptwbInfo <= '{rob_idx : s1_fuInfo.robIdx, except_type : s1_ldexcept};

            load_finished <= s2_vld || load_except;
            commwbInfo <= '{
                rob_idx : s2_fuInfo.robIdx,
                irob_idx : s2_fuInfo.irobIdx,
                use_imm : s2_fuInfo.useImm,
                rd_wen : s2_fuInfo.rdwen,
                iprd_idx : s2_fuInfo.iprd,
                result : (load_except ? 0 : sext_data)
            };
        end
    end

    assign o_fu_finished = load_finished;
    assign o_comwbInfo = commwbInfo;

    assign o_has_except = load_except;
    assign o_exceptwbInfo = exceptwbInfo;

endmodule



