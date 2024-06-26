`include "frontend_define.svh"

import "DPI-C" function void ftq_writeback(
    uint64_t startAddr,
    uint64_t endAddr,
    uint64_t targetAddr,
    uint64_t mispred,
    uint64_t taken,
    uint64_t branchType
);

import "DPI-C" function void ftq_commit(
    uint64_t startAddr,
    uint64_t endAddr,
    uint64_t targetAddr,
    uint64_t taken,
    uint64_t branchType
);
import "DPI-C" function void count_falsepred(uint64_t n);

typedef struct {
    logic [`XDEF] startAddr;
    logic [`XDEF] endAddr;
    logic taken;
    logic [`XDEF] nextAddr;
} ftqFetchInfo_t;

typedef struct {
    logic wasWrote;
    logic mispred;
    logic taken;
    logic [
    `SDEF(`FTB_PREDICT_WIDTH)
    ] fallthruOffset;  // in backend: branch's offset + isRVC ? 2:4
    logic [`XDEF] targetAddr;
    BranchType::_ branch_type;
    //we need fallthruAddr to update ftb
} ftqBranchInfo_t;  // branch writeback

typedef struct {
    // ubtb meta
    logic hit_on_ubtb;
    // ftb meta
    logic hit_on_ftb;
} ftqMetaInfo_t;

// DESIGN:
//  if preDecode found falsepred and correct fetch stream
// we need to writeback the new npc
module FTQ (
    input wire clk,
    input wire rst,
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    input wire i_stall,
    input wire i_falsepred,
    input ftqIdx_t i_recovery_idx,
    input branchwbInfo_t i_preDecodewbInfo,  // from preDecode writeback

    // from BPU
    input wire i_pred_req,
    output wire o_ftq_rdy,
    input BPInfo_t i_pred_ftqInfo,
    // to BPU update
    output wire o_bpu_commit,
    input wire i_bpu_update_finished,
    output BPupdateInfo_t o_BPUupdateInfo,

    // to icache
    output wire o_icache_fetch_req,
    output ftqIdx_t o_icache_fetch_ftqIdx,
    input wire i_icache_fetch_rdy,
    output ftq2icacheInfo_t o_icache_fetchInfo,

    // from backend read
    input ftqIdx_t i_read_ftqIdx[`BRU_NUM + `LDU_NUM + `STU_NUM],
    output wire [`XDEF] o_read_ftqStartAddr[`BRU_NUM + `LDU_NUM + `STU_NUM],
    output wire [`XDEF] o_read_ftqNextAddr[`BRU_NUM + `LDU_NUM + `STU_NUM],

    // from backend writeback
    input wire [`WDEF(`BRU_NUM)] i_backend_branchwb_vld,
    input branchwbInfo_t i_backend_branchwbInfo[`BRU_NUM],

    // from backend commit
    input wire i_commit_vld,
    input ftqIdx_t i_commit_ftqIdx
);

    genvar i;

    ftqIdx_t pred_ptr;  // from BPU
    ftqIdx_t fetch_ptr;  // to ICACHE
    ftqIdx_t commit_ptr;  // from rob
    ftqIdx_t commit_ptr_thre;  // commit_ptr -> commit_ptr_thre
    ftqIdx_t nxt_commit_ptr_thre;
    reg pptr_flipped, fptr_flipped, cptr_flipped;

    ftqFetchInfo_t buf_baseInfo[`FTQ_SIZE];
    ftqBranchInfo_t buf_brInfo[`FTQ_SIZE];
    ftqMetaInfo_t buf_metaInfo[`FTQ_SIZE];

    reg [`WDEF(`FTQ_SIZE)] buffer_vld;
    reg [`WDEF(`FTQ_SIZE)] falsepred_vec;
    wire [`WDEF(`FTQ_SIZE)] buffer_mispred;

    wire bpu_commit;
    wire ftqEmpty = (commit_ptr == pred_ptr) && (cptr_flipped == pptr_flipped);
    wire ftqFull = (commit_ptr == pred_ptr) && (cptr_flipped != pptr_flipped);
    wire [`SDEF(`FTQ_SIZE)] push, pop;
    assign push = (i_pred_req && (!ftqFull) ? 1 : 0);
    assign pop = ((do_commit && (bpu_commit ? i_bpu_update_finished : 1)) ? 1 : 0);
    assign o_ftq_rdy = (!ftqFull);

    generate
        for (i = 0; i < `FTQ_SIZE; i = i + 1) begin
            assign buffer_mispred[i] = buf_brInfo[i].mispred;
        end
    endgenerate

    /****************************************************************************************************/
    // do update for ptr
    // NOTE: we need to commit mispred ftq entry quickly
    /****************************************************************************************************/
    wire do_pred = i_pred_req && o_ftq_rdy && (!i_falsepred);
    wire do_commit = commit_ptr != commit_ptr_thre;

    // BPU fetch requet bypass to Icache
    wire BP_bypass = (!ftqFull) && (fetch_ptr == pred_ptr) && do_pred;
    wire do_fetch = ((!ftqEmpty) && (fetch_ptr != pred_ptr) && (!i_stall)) || BP_bypass;

    assign nxt_commit_ptr_thre = (i_commit_vld ? i_commit_ftqIdx : commit_ptr_thre);
    always_ff @(posedge clk) begin
        if (rst) begin
            pred_ptr <= 0;
            fetch_ptr <= 0;
            commit_ptr <= 0;
            commit_ptr_thre <= 0;
            buffer_vld <= 0;
            falsepred_vec <= 0;
            pptr_flipped <= 0;
            fptr_flipped <= 0;
            cptr_flipped <= 0;
        end
        else begin
            if (i_squash_vld) begin
                pred_ptr <= nxt_commit_ptr_thre;
                fetch_ptr <= nxt_commit_ptr_thre;
                if (nxt_commit_ptr_thre >= commit_ptr) begin
                    pptr_flipped <= cptr_flipped;
                    fptr_flipped <= cptr_flipped;
                end
                else begin
                    pptr_flipped <= (!cptr_flipped);
                    fptr_flipped <= (!cptr_flipped);
                end
                for (int fa = 0; fa < `FTQ_SIZE; fa = fa + 1) begin
                    if ((commit_ptr <= nxt_commit_ptr_thre) && (fa >= commit_ptr) && (fa < nxt_commit_ptr_thre)) begin
                    end
                    else if ((commit_ptr > nxt_commit_ptr_thre) && ((fa >= commit_ptr) || (fa < nxt_commit_ptr_thre))) begin
                    end
                    else begin
                        buffer_vld[fa] <= 0;
                    end
                end
            end
            else begin
                if (i_falsepred) begin
                    pred_ptr <= i_recovery_idx;
                    pptr_flipped <= (i_recovery_idx > pred_ptr) ? ~pptr_flipped : pptr_flipped;
                    for (int fa = 0; fa < `FTQ_SIZE; fa = fa + 1) begin
                        if ((i_recovery_idx > pred_ptr) && ((fa >= i_recovery_idx) || (fa < pred_ptr))) begin
                            buffer_vld[fa] <= 0;
                        end
                        else if ((i_recovery_idx <= pred_ptr) && ((fa >= i_recovery_idx) && (fa < pred_ptr))) begin
                            buffer_vld[fa] <= 0;
                        end
                    end
                end
                else if (do_pred) begin
                    // do pred
                    assert (buffer_vld[pred_ptr] == 0);
                    buffer_vld[pred_ptr] <= 1;
                    falsepred_vec[pred_ptr] <= 0;
                    pred_ptr <= (pred_ptr == (`FTQ_SIZE - 1)) ? 0 : pred_ptr + 1;
                    pptr_flipped <= (pred_ptr == (`FTQ_SIZE - 1)) ? ~pptr_flipped : pptr_flipped;
                end

                // do fetch
                if (i_stall || i_falsepred) begin
                    fetch_ptr <= i_recovery_idx;
                    fptr_flipped <= (i_recovery_idx > pred_ptr) ? ~pptr_flipped : pptr_flipped;
                end
                else if (do_fetch && i_icache_fetch_rdy) begin
                    fetch_ptr <= (fetch_ptr == (`FTQ_SIZE - 1)) ? 0 : fetch_ptr + 1;
                    fptr_flipped <= (fetch_ptr == (`FTQ_SIZE - 1)) ? ~fptr_flipped : fptr_flipped;
                end
            end

            // do commit
            if (do_commit) begin
                if (bpu_commit ? i_bpu_update_finished : 1) begin
                    assert (buffer_vld[commit_ptr]);
                    buffer_vld[commit_ptr] <= 0;
                    commit_ptr <= (commit_ptr == (`FTQ_SIZE - 1)) ? 0 : commit_ptr + 1;
                    cptr_flipped <= (commit_ptr == (`FTQ_SIZE - 1)) ? ~cptr_flipped : cptr_flipped;

                    if (falsepred_vec[commit_ptr]) begin
                        count_falsepred(1);
                    end
                end
            end

            if (i_commit_vld) begin
                commit_ptr_thre <= i_commit_ftqIdx;
            end
        end
    end

    /****************************************************************************************************/
    // BPU insert into FTQ
    /****************************************************************************************************/

    reg [`XDEF]
        read_ftqStartAddr[`BRU_NUM + `LDU_NUM + `STU_NUM],
        read_ftqNextAddr[`BRU_NUM + `LDU_NUM + `STU_NUM];
    assign o_read_ftqStartAddr = read_ftqStartAddr;
    assign o_read_ftqNextAddr = read_ftqNextAddr;

    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
        end
        else begin
            // read
            for (fa = 0; fa < `BRU_NUM + `LDU_NUM + `STU_NUM; fa = fa + 1) begin
                read_ftqStartAddr[fa] <= buf_baseInfo[i_read_ftqIdx[fa]].startAddr;
                read_ftqNextAddr[fa] <= buf_baseInfo[i_read_ftqIdx[fa]].nextAddr;
            end

            if (do_pred) begin
                buf_baseInfo[pred_ptr] <= '{
                    startAddr : i_pred_ftqInfo.startAddr,
                    endAddr   : i_pred_ftqInfo.endAddr,
                    taken     : i_pred_ftqInfo.taken,
                    nextAddr  : i_pred_ftqInfo.nextAddr
                };
                buf_metaInfo[pred_ptr] <= '{
                    hit_on_ubtb : i_pred_ftqInfo.hit_on_ubtb,
                    hit_on_ftb  : i_pred_ftqInfo.hit_on_ftb
                };
            end
            if (i_falsepred) begin
                falsepred_vec[i_preDecodewbInfo.ftq_idx] <= 1;
                buf_baseInfo[i_preDecodewbInfo.ftq_idx].nextAddr <= i_preDecodewbInfo.branch_npc;
            end
        end
    end


    /****************************************************************************************************/
    // writeback/read from backend
    /****************************************************************************************************/

    wire [`WDEF(`BRU_NUM)] can_wb;
    branchwbInfo_t branchwbInfo[`BRU_NUM];
    generate
        for (i = 0; i < `BRU_NUM; i = i + 1) begin
            assign can_wb[i] = i_backend_branchwb_vld[i];
            assign branchwbInfo[i] = i_backend_branchwbInfo[i];
        end
    endgenerate

    always_ff @(posedge clk) begin
        int fa, fb;
        if (rst) begin
        end
        else begin
            // write by backend
            for (fa = 0; fa < `BRU_NUM; fa = fa + 1) begin
                if (can_wb[fa]) begin
                    assert (buffer_vld[branchwbInfo[fa].ftq_idx]);
                    // only allow write once
                    assert (buf_brInfo[branchwbInfo[fa].ftq_idx].wasWrote == 0);
                    buf_brInfo[branchwbInfo[fa].ftq_idx] <= '{
                        wasWrote       : 1,
                        mispred        : branchwbInfo[fa].has_mispred,
                        taken          : branchwbInfo[fa].branch_taken,
                        fallthruOffset : branchwbInfo[fa].fallthruOffset,
                        targetAddr     : branchwbInfo[fa].target_pc,
                        branch_type    : branchwbInfo[fa].branch_type
                    };
                    ftq_writeback(
                        buf_baseInfo[branchwbInfo[fa].ftq_idx].startAddr,
                        buf_baseInfo[branchwbInfo[fa].ftq_idx].startAddr + branchwbInfo[fa].fallthruOffset,
                        branchwbInfo[fa].target_pc,
                        branchwbInfo[fa].has_mispred,
                        branchwbInfo[fa].branch_taken,
                        branchwbInfo[fa].branch_type);
                end
            end

            if (do_pred) begin
                // buf_brInfo[pred_ptr].vld <= 0;
                // set default value
                buf_brInfo[pred_ptr] <= '{
                    wasWrote       : 0,
                    mispred        : 0,  // default set false
                    taken          : i_pred_ftqInfo.taken,
                    fallthruOffset :
                    i_pred_ftqInfo.endAddr
                    -
                    i_pred_ftqInfo.startAddr,
                    targetAddr     : i_pred_ftqInfo.targetAddr,
                    branch_type    : i_pred_ftqInfo.branch_type
                };
            end

            // branch wb check assert
            for (fa = 0; fa < `BRU_NUM; fa = fa + 1) begin
                for (fb = 0; fb < `BRU_NUM; fb = fb + 1) begin
                    if (fa == fb) begin
                    end
                    else if (i_backend_branchwb_vld[fa] && i_backend_branchwb_vld[fb]) begin
                        assert (i_backend_branchwbInfo[fa].ftq_idx != i_backend_branchwbInfo[fb].ftq_idx);
                    end
                end
            end
        end
    end


    /****************************************************************************************************/
    // commit and update ftq entry
    /****************************************************************************************************/

    wire [`XDEF] temp_fallthruAddr = buf_baseInfo[commit_ptr].startAddr + buf_brInfo[commit_ptr].fallthruOffset;

    BPupdateInfo_t new_updateInfo;
    assign new_updateInfo = '{
            startAddr    : buf_baseInfo[commit_ptr].startAddr,
            fallthruAddr : temp_fallthruAddr,
            targetAddr   : buf_brInfo[commit_ptr].targetAddr,
            branch_type  : buf_brInfo[commit_ptr].branch_type,
            taken        : buf_brInfo[commit_ptr].taken,
            mispred      : buffer_mispred[commit_ptr],
            // ubtb meta
            hit_on_ubtb  :
            buf_metaInfo[
            commit_ptr
            ].hit_on_ubtb,
            // ftb meta
            hit_on_ftb   :
            buf_metaInfo[
            commit_ptr
            ].hit_on_ftb
        };

    assign bpu_commit = (buf_brInfo[commit_ptr].branch_type != BranchType::isNone) && do_commit;
    assign o_bpu_commit = bpu_commit;
    assign o_BPUupdateInfo = new_updateInfo;

    always_ff @(posedge clk) begin
        if (rst) begin
        end
        else begin
            if (bpu_commit) begin
                ftq_commit(buf_baseInfo[commit_ptr].startAddr,
                           temp_fallthruAddr, buf_brInfo[commit_ptr].targetAddr,
                           buf_brInfo[commit_ptr].taken,
                           buf_brInfo[commit_ptr].branch_type);
            end
        end
    end

    /****************************************************************************************************/
    // send request to icache
    // if FTQ is empty we can bypass the BPU request to Icache
    /****************************************************************************************************/

    assign o_icache_fetch_req = do_fetch;
    assign o_icache_fetch_ftqIdx = BP_bypass ? pred_ptr : fetch_ptr;

    // from ftq
    ftq2icacheInfo_t fetchInfo;
    assign fetchInfo = '{
            startAddr : buf_baseInfo[fetch_ptr].startAddr,
            // TODO: use byte mask
            fetchBlock_size :
            buf_baseInfo[fetch_ptr].endAddr
            -
            buf_baseInfo[fetch_ptr].startAddr,
            taken : buf_baseInfo[fetch_ptr].taken,
            nextAddr : buf_baseInfo[fetch_ptr].nextAddr
        };

    // from bpu bypass
    ftq2icacheInfo_t BP_bypass_fetchInfo;
    assign BP_bypass_fetchInfo = '{
            startAddr : i_pred_ftqInfo.startAddr,
            // endAddr is fallthruAddr
            // fetchBlock_size = 4 * n
            fetchBlock_size :
            i_pred_ftqInfo.endAddr
            -
            i_pred_ftqInfo.startAddr,
            taken : i_pred_ftqInfo.taken,
            nextAddr : i_pred_ftqInfo.nextAddr
        };

    assign o_icache_fetchInfo = BP_bypass ? BP_bypass_fetchInfo : fetchInfo;

    // `ASSERT(do_fetch ? (buf_baseInfo[fetch_ptr].endAddr > buf_baseInfo[fetch_ptr].startAddr) : 1);
    // `ASSERT(do_fetch ? (buf_baseInfo[fetch_ptr].endAddr - buf_baseInfo[fetch_ptr].startAddr <= 64) : 1);


endmodule




