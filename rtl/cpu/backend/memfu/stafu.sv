`include "backend_define.svh"





// NOTE:
// if ld0 has dep on st0
// ld0 can't execute parallel with st0
module stafu (
    input wire clk,
    input wire rst,

    output wire o_stall,
    input wire i_vld,
    input exeInfo_t i_fuInfo,

    output wire o_issue_success,
    output wire o_issue_replay,
    output iqIdx_t o_feedback_iqIdx,

    sta2mmu_if.m if_sta2mmu,
    staviocheck_if.m if_staviocheck,
    store2que_if.m if_sta2que,

    output wire o_has_except,
    output exceptwbInfo_t o_exceptwbInfo
);
    // calculate store addr
    // check memory violation
    genvar i;

    reg s0_vld;
    exeInfo_t s0_fuInfo;

    always_ff @(posedge clk) begin
        if (rst) begin
            s0_vld;
        end
        else begin
            s0_vld <= i_vld;
            s0_fuInfo <= i_fuInfo;
        end
    end

    // s0: calculate addr, mmu check
    wire [`XDEF] s0_vaddr;
    assign s0_vaddr = s0_fuInfo.srcs[0] + s0_fuInfo.srcs[1];

    wire [`WDEF(`XLEN/8)] s0_store_vec;
    wire [`WDEF($clog2(8))] s0_store_size;
    wire store_misaligned;
    assign s0_store_vec =
    (s0_fuInfo.micOp == MicOp_t::sb) ? (8'b0000_0001 << s0_vaddr[2:0]) :
    (s0_fuInfo.micOp == MicOp_t::sh) ? (8'b0000_0011 << s0_vaddr[2:0]) :
    (s0_fuInfo.micOp == MicOp_t::sw) ? (8'b0000_1111 << s0_vaddr[2:0]) :
    8'b1111_1111;

    assign s0_store_size =
    (s0_fuInfo.micOp == MicOp_t::sb) ? 1 :
    (s0_fuInfo.micOp == MicOp_t::sh) ? 2 :
    (s0_fuInfo.micOp == MicOp_t::sw) ? 4 :
    8 ;

    assign store_misaligned = (s0_vaddr[2:0] & (s0_store_size - 1)) != 0;

    assign if_sta2mmu.s0_req = s0_vld && !store_misaligned;
    assign if_sta2mmu.s0_vaddr = s0_vaddr;

    // s1: get paddr
    reg s1_vld;
    reg s1_misaligned;
    logic [`XDEF] s1_vaddr;
    exeInfo_t s1_fuInfo;
    always_ff @(posedge clk) begin
        if (rst) begin
            s1_vld <= 0;
            s1_misaligned <= 0;
        end
        else begin
            s1_vld <= s0_vld;
            s1_vaddr <= s0_vaddr;
            s1_fuInfo <= s0_fuInfo;
            s1_misaligned <= store_misaligned;
        end
    end

    wire s1_replay = if_sta2mmu.s1_miss | if_sta2mmu.s1_mmio;
    wire s1_fault = s1_misaligned | if_sta2mmu.s1_pagefault | if_sta2mmu.s1_illegaAddr;

    // write back storeque
    assign if_sta2que.vld = s1_vld && !s1_replay && !s1_fault;
    assign if_sta2que.sqIdx = s1_fuInfo.sqIdx;
    assign if_sta2que.vaddr = s1_vaddr;
    assign if_sta2que.paddr = if_sta2mmu.s1_paddr;

    // notify IQ
    assign o_issue_success = s1_vld && (!s1_replay);
    assign o_issue_replay = s1_vld && s1_replay;
    assign o_feedback_iqIdx = s1_fuInfo.iqIdx;

    // check violation
    assign if_staviocheck.vld = s2_vld;
    assign if_staviocheck.sqIdx = s2_fuInfo.sqIdx;
    assign if_staviocheck.paddr = if_sta2mmu.s1_paddr;
    assign if_staviocheck.mask = 0;

    // s1: write except
    assign o_has_except = s1_vld && s1_fault;
    assign o_exceptwbInfo = '{
            rob_idx : s1_fuInfo.robIdx,
            except_type :
            s1_misaligned
            ?
            rv_trap_t::storeMisaligned
            :
            if_sta2mmu.s1_pagefault
            ?
            rv_trap_t::storePageFault
            :
            rv_trap_t::storeFault
        };

    // s2: check violation finish
    reg s2_vld;
    exeInfo_t s2_fuInfo;
    always_ff @(posedge clk) begin
        if (rst) begin
            s2_vld <= 0;
            store_finished <= 0;
        end
        else begin
            s2_vld <= s1_vld;
            s2_fuInfo <= s1_fuInfo;
        end
    end

    // s3: store finish
    reg store_finished;
    always_ff @(posedge clk) begin
        if (rst) begin
            store_finished <= 0;
        end
        else begin
            store_finished <= s2_vld;
            
        end
    end


endmodule
