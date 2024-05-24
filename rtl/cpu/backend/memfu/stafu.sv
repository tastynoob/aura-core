`include "backend_define.svh"



import "DPI-C" function void memory_violation_find(
    uint64_t ldpc,
    uint64_t stpc
);

import "DPI-C" function void set_store_load_info(
    uint64_t seqNum,
    uint64_t isload,
    uint64_t paddr,
    uint64_t size
);

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

    output wire o_fu_finished,
    output comwbInfo_t o_comwbInfo,

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
            s0_vld <= 0;
        end
        else begin
            s0_vld <= i_vld;
            s0_fuInfo <= i_fuInfo;
            if (i_vld) begin
                update_instPos(i_fuInfo.seqNum, difftest_def::AT_fu);
            end
        end
    end

    // s0: calculate addr, mmu check
    wire [`XDEF] s0_vaddr;
    assign s0_vaddr = s0_fuInfo.srcs[0] + s0_fuInfo.srcs[1];

    wire [`WDEF(`XLEN/8)] s0_store_vec;  // 8 byte aligned
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
    reg [`WDEF(`XLEN/8)] s1_storemask;
    exeInfo_t s1_fuInfo;
    always_ff @(posedge clk) begin
        if (rst) begin
            s1_vld <= 0;
            s1_misaligned <= 0;
        end
        else begin
            s1_vld <= s0_vld;
            s1_vaddr <= s0_vaddr;
            s1_storemask <= s0_store_vec;
            s1_fuInfo <= s0_fuInfo;
            s1_misaligned <= store_misaligned;
        end
    end

    wire s1_replay = if_sta2mmu.s1_miss | if_sta2mmu.s1_mmio;
    wire s1_fault = s1_misaligned | if_sta2mmu.s1_pagefault | if_sta2mmu.s1_illegaAddr;

    // notify IQ
    assign o_issue_success = s1_vld && (!s1_replay);
    assign o_issue_replay = s1_vld && s1_replay;
    assign o_feedback_iqIdx = s1_fuInfo.iqIdx;

    // write back storeque
    assign if_sta2que.vld = s1_vld && !s1_replay && !s1_fault;
    assign if_sta2que.sqIdx = s1_fuInfo.sqIdx;
    assign if_sta2que.robIdx = s1_fuInfo.robIdx;
    assign if_sta2que.vaddr = s1_vaddr;
    assign if_sta2que.paddr = if_sta2mmu.s1_paddr;
    assign if_sta2que.storemask = s1_storemask;

    // check violation
    assign if_staviocheck.vld = s1_vld && !s1_replay && !s1_fault;
    assign if_staviocheck.sqIdx = s1_fuInfo.sqIdx;
    assign if_staviocheck.paddr = if_sta2mmu.s1_paddr;
    assign if_staviocheck.mask = s1_storemask;

    // s2: get vio result, notify rob
    wire violation = if_staviocheck.vio;
    robIdx_t vioload_robIdx = if_staviocheck.vioload_robIdx;
    robIdx_t viostore_robIdx = s2_fuInfo.robIdx;
    wire [`XDEF] vioload_pc = if_staviocheck.vioload_pc;
    wire [`XDEF] viostore_pc = s2_fuInfo.pc;
    reg s2_vld;
    exeInfo_t s2_fuInfo;
    reg prev_has_except;
    rv_trap_t::exception prev_except;
    always_ff @(posedge clk) begin
        if (rst) begin
            s2_vld <= 0;
            prev_has_except <= 0;
        end
        else begin
            s2_vld <= s1_vld;
            s2_fuInfo <= s1_fuInfo;
            prev_has_except <= s1_vld && s1_fault;
            prev_except <= s1_misaligned ? rv_trap_t::storeMisaligned :
            if_sta2mmu.s1_pagefault ? rv_trap_t::storePageFault :
            rv_trap_t::storeFault;

            if (violation) begin
                memory_violation_find(vioload_pc, viostore_pc);
            end

            if (s1_vld) begin
                set_store_load_info(s1_fuInfo.seqNum, 0, if_sta2mmu.s1_paddr, count_one(s1_storemask));
            end
        end
    end

    // s2: write except
    assign o_has_except = prev_has_except || violation;
    assign o_exceptwbInfo = '{
            rob_idx : prev_has_except ? s2_fuInfo.robIdx : vioload_robIdx,
            except_type : prev_has_except ? prev_except : rv_trap_t::reExec,
            stpc: viostore_pc,
            ldpc: vioload_pc
        };

    // s3: store finish
    reg store_finished;
    comwbInfo_t commwbInfo;
    always_ff @(posedge clk) begin
        if (rst) begin
            store_finished <= 0;
        end
        else begin
            store_finished <= s2_vld;
            commwbInfo <= '{
                rob_idx : s2_fuInfo.robIdx,
                irob_idx : s2_fuInfo.irobIdx,
                use_imm : s2_fuInfo.useImm,
                rd_wen : 0,
                iprd_idx : 0,
                result : 0
            };
            if (s2_vld) begin
                update_instPos(s2_fuInfo.seqNum, difftest_def::AT_wb);
            end
        end
    end

    assign o_fu_finished = store_finished;
    assign o_comwbInfo = commwbInfo;


endmodule
