
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
    input lsfuInfo_t i_fuInfo,
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
    output exceptwbInfo_t o_exceptwbInfo
);

    reg s0_vld;
    wire s0_continue;
    lsfuInfo_t s0_fuInfo;

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
    wire loadaddr_misaligned;
    assign s0_vaddr = s0_fuInfo.srcs[0] + s0_fuInfo.srcs[1];
    assign s0_load_vec =
    ((s0_fuInfo.micOp == MicOp_t::lb) || (s0_fuInfo.micOp == MicOp_t::lbu)) ? 8'b0000_0001 :
    ((s0_fuInfo.micOp == MicOp_t::lh) || (s0_fuInfo.micOp == MicOp_t::lhu)) ? 8'b0000_0011 :
    ((s0_fuInfo.micOp == MicOp_t::lw) || (s0_fuInfo.micOp == MicOp_t::lwu)) ? 8'b0000_1111 :
    8'b1111_1111 ;

    assign s0_load_size =
    ((s0_fuInfo.micOp == MicOp_t::lb) || (s0_fuInfo.micOp == MicOp_t::lbu)) ? 1 :
    ((s0_fuInfo.micOp == MicOp_t::lh) || (s0_fuInfo.micOp == MicOp_t::lhu)) ? 2 :
    ((s0_fuInfo.micOp == MicOp_t::lw) || (s0_fuInfo.micOp == MicOp_t::lwu)) ? 4 :
    8 ;

    // dont care
    assign loadaddr_misaligned = (s0_vaddr[$clog2(`CACHELINE_SIZE)-1 : 0] + s0_load_size <= `CACHELINE_SIZE);

    /********************/
    // s0: send vaddr to tlb, tag sram
    assign if_load2cache.s0_req = s0_vld;
    assign if_load2cache.s0_lqIdx = s0_fuInfo.lq_idx;
    assign if_load2cache.s0_vaddr = s0_vaddr;// fully addr
    assign if_load2cache.s0_load_vec = s0_load_vec;

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
    lsfuInfo_t s1_fuInfo;
    reg[`WDEF(`XLEN/8)] s1_load_vec;
    reg s1_vld;
    wire s1_cacherdy;
    lqIdx_t s1_lqIdx;

    wire s1_replay;// s1 replay due to tlb miss, cache miss
    wire s1_continue;
    wire s1_conflict;
    wire s1_tlbhit;
    wire s1_addrMisaligned;// addr misaligned should be check by tlb, because it may be mmio access
    wire s1_cachehit;
    paddr_t s1_paddr;
    always_ff @( posedge clk ) begin
        if (rst) begin
            s1_vld <= 0;
        end
        else if (s1_addrMisaligned) begin
            // addr misaligneded exception;
            s1_vld <= 0;
        end
        else begin
            s1_fuInfo <= s0_fuInfo;
            s1_load_vec <= s0_load_vec;
            s1_vld <= s0_vld;
            s1_lqIdx <= s0_fuInfo.lq_idx;
        end
    end

    assign if_load2cache.s1_req = s1_vld;

    assign s1_cacherdy = if_load2cache.s1_rdy;
    assign s1_conflict = if_load2cache.s1_conflict;
    assign s1_tlbhit = if_load2cache.s1_tlbhit;
    assign s1_addrMisaligned = if_load2cache.s1_addrMisaligned;
    assign s1_cachehit = if_load2cache.s1_cachehit;
    assign s1_paddr = if_load2cache.s1_paddr;

    assign s1_continue = s1_vld && ((s1_tlbhit && !s1_conflict));
    assign s1_replay = s1_vld && (!s1_tlbhit || s1_cachehit || s1_conflict);

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
    assign uf_stfwd.s1_paddr = s1_paddr;

    // if cache miss, load pipe should notify loadQue

    /********************/
    // s2
    // get the dcache data
    // get the forward data
    // if cachemiss, write the forward data to loadque
    lsfuInfo_t s2_fuInfo;
    reg s2_vld;
    reg s2_cachemiss;
    wire s2_replay;
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
    assign s2_cacheline = if_load2cache.s2_data;

    // notify loadQue, writeback forward data if cachemiss

    assign if_load2que.s2_lqIdx = s2_fuInfo.lq_idx;
    assign if_load2que.s2_finished = 0;
    assign if_load2que.s2_except = 0;
    assign if_load2que.s2_fwd = if_stfwd.s2_match && (!if_stfwd.s2_data_nrdy);
    assign if_load2que.s2_match_vec = if_stfwd.s2_match_vec;
    assign if_load2que.s2_fwd_data = if_stfwd.s2_fwd_data;


    assign s2_replay = if_stfwd.s2_match && if_stfwd.s2_data_nrdy;


    /********************/
    // s3
    // merge data and output
    reg load_finished;
    comwbInfo_t commwbInfo;
    exceptwbInfo_t exceptwbInfo;
    always_ff @( posedge clk ) begin
        if (rst) begin
            load_finished <= 0;
        end
        else if (s1_addrMisaligned) begin
            load_finished <= 0;
            // early finish due to exception
            exceptwbInfo <= '{
                rob_idx : s2_fuInfo.rob_idx,
                except_type : rv_trap_t::loadMisaligneded
            };
            commwbInfo <= '{
                rob_idx : s2_fuInfo.rob_idx,
                irob_idx : s2_fuInfo.irob_idx,
                use_imm : s2_fuInfo.use_imm,
                rd_wen : s2_fuInfo.rd_wen,
                iprd_idx : s2_fuInfo.iprd_idx,
                result : 0
            };
        end
        else if (s2_vld) begin
            load_finished <= 0;
            commwbInfo <= '{
                rob_idx : s2_fuInfo.rob_idx,
                irob_idx : s2_fuInfo.irob_idx,
                use_imm : s2_fuInfo.use_imm,
                rd_wen : s2_fuInfo.rd_wen,
                iprd_idx : s2_fuInfo.iprd_idx,
                result : 0
            };
        end
    end

    assign o_fu_finished = load_finished;



endmodule



