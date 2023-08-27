`include "frontend_define.svh"


typedef struct {
    logic[`XDEF] startAddr;
    logic[`XDEF] endAddr;
    logic[`XDEF] nextAddr;
} ftqFetchInfo_t;

typedef struct {
    logic mispred;
    logic taken;
    ftqOffset_t fallthruOffset;// in backend: branch's offset + isRVC ? 2:4
    logic[`XDEF] targetAddr;
    BranchType::_ branch_type;
    //we need fallthruAddr to update ftb
} ftqBranchInfo_t;// branch writeback

typedef struct {
    // ftb meta
    logic hit_on_ftb;
    logic[`WDEF(2)] ftb_counter;
} ftqMetaInfo_t;

// DESIGN:
// when squash, the ftq[commit_ftqIdx] is mispred fetch block
module FTQ (
    input wire clk,
    input wire rst,
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    input wire i_stall,
    input ftqIdx_t i_recovery_idx,

    // from BPU
    input wire i_pred_req,
    output wire o_ftq_rdy,
    input ftqInfo_t i_pred_ftqInfo,
    // to BPU update
    output wire o_bpu_update,
    input wire i_bpu_update_finished,
    output BPupdateInfo_t o_BPUupdateInfo,

    // to icache
    output wire o_icache_fetch_req,
    output ftqIdx_t o_icache_fetch_ftqIdx,
    input wire i_icache_fetch_rdy,
    output ftq2icacheInfo_t o_icache_fetchInfo,

    // from backend read
    input ftqIdx_t i_read_ftqIdx[`BRU_NUM],
    output wire[`XDEF] o_read_ftqStartAddr[`BRU_NUM],
    output wire[`XDEF] o_read_ftqNextAddr[`BRU_NUM],

    // from backend writeback
    input wire[`WDEF(`BRU_NUM)] i_backend_branchwb_vld,
    input branchwbInfo_t i_backend_branchwbInfo[`BRU_NUM],

    // from backend commit
    input wire i_commit_vld,
    input ftqIdx_t i_commit_ftqIdx
);

    genvar i;

    ftqIdx_t pred_ptr; // from BPU
    ftqIdx_t fetch_ptr; // to ICACHE
    ftqIdx_t commit_ptr; // from rob
    ftqIdx_t commit_ptr_thre;// commit_ptr -> commit_ptr_thre
    reg[`SDEF(`FTQ_SIZE)] count;

    ftqFetchInfo_t buffer_fetchInfo[`FTQ_SIZE];
    ftqBranchInfo_t buffer_branchInfo[`FTQ_SIZE];
    ftqMetaInfo_t buffer_metaInfo[`FTQ_SIZE];
    reg[`WDEF(`FTQ_SIZE)] buffer_vld;

    wire notFull = (count != `FTQ_SIZE);
    assign o_ftq_rdy = notFull;

/****************************************************************************************************/
// do update for ptr
// NOTE: we need to commit mispred ftq entry quickly
/****************************************************************************************************/

    wire do_commit = (commit_ptr != commit_ptr_thre);
    wire do_fetch = (count != 0) && (fetch_ptr != pred_ptr) && (!i_stall);
    wire need_update_ftb = (buffer_metaInfo[commit_ptr].hit_on_ftb || buffer_branchInfo[commit_ptr].mispred) && do_commit;

    wire[`SDEF(`FTQ_SIZE)] push,pop;
    assign push = (i_pred_req && notFull ? 1 : 0);
    assign pop = (do_commit && (need_update_ftb ? i_bpu_update_finished : 1) ? 1 : 0);

    always_ff @( posedge clk ) begin
        if (rst) begin
            pred_ptr <= 0;
            fetch_ptr <= 0;
            commit_ptr <= 0;
            commit_ptr_thre <= 0;
            count <= 0;
            buffer_vld <= 0;
        end
        else begin

            count <= count + push - pop;

            if (i_pred_req && notFull) begin
                assert(buffer_vld[pred_ptr] == 0);
                buffer_vld[pred_ptr] <= 1;
                pred_ptr <= (pred_ptr == (`FTQ_SIZE - 1)) ? 0 : pred_ptr + 1;
            end

            // do commit
            // TODO: make commit and ftb commit separate
            if (do_commit) begin
                if (need_update_ftb ? i_bpu_update_finished : 1) begin
                    assert(buffer_vld[commit_ptr]);
                    buffer_vld[commit_ptr] <= 0;
                    commit_ptr <= (commit_ptr == (`FTQ_SIZE - 1)) ? 0 : commit_ptr + 1;
                end
            end

            if (do_fetch && i_icache_fetch_rdy) begin
                fetch_ptr <= (fetch_ptr == (`FTQ_SIZE - 1)) ? 0 : fetch_ptr + 1;
            end
            else if (i_stall) begin
                fetch_ptr <= i_recovery_idx;
            end

            if (i_commit_vld) begin
                buffer_branchInfo[i_commit_ftqIdx].mispred = 0;
                if (buffer_branchInfo[i_commit_ftqIdx].mispred) begin
                    assert(0);
                    commit_ptr_thre <= (i_commit_ftqIdx == (`FTQ_SIZE-1)) ? 0 : i_commit_ftqIdx + 1;
                    $display("mispred %b : %h", buffer_branchInfo[i_commit_ftqIdx].mispred, i_commit_ftqIdx);
                end
                else begin
                    commit_ptr_thre <= i_commit_ftqIdx;
                end
            end
        end
    end

    //`ASSERT(buffer_branchInfo[i_commit_ftqIdx].mispred == 0);
/****************************************************************************************************/
// BPU insert into FTQ
/****************************************************************************************************/

    always_ff @( posedge clk ) begin
        if (rst) begin
        end
        else begin
            if (i_pred_req && notFull) begin
                buffer_fetchInfo[pred_ptr] <= '{
                    startAddr : i_pred_ftqInfo.startAddr,
                    endAddr   : i_pred_ftqInfo.endAddr,
                    nextAddr  : i_pred_ftqInfo.taken ? i_pred_ftqInfo.targetAddr : i_pred_ftqInfo.endAddr+1
                };

                buffer_metaInfo[pred_ptr] <= '{
                    hit_on_ftb  : i_pred_ftqInfo.hit_on_ftb,
                    ftb_counter : i_pred_ftqInfo.ftb_counter
                };
            end
        end
    end


/****************************************************************************************************/
// writeback/read from backend
/****************************************************************************************************/

    branchwbInfo_t branchwbInfo[`BRU_NUM];
    generate
        for(i=0;i<`BRU_NUM;i=i+1) begin:gen_for
            assign branchwbInfo[i] = i_backend_branchwbInfo[i];
        end
    endgenerate


    reg[`XDEF] read_ftqStartAddr[`BRU_NUM], read_ftqNextAddr[`BRU_NUM];
    assign o_read_ftqStartAddr = read_ftqStartAddr;
    assign o_read_ftqNextAddr = read_ftqNextAddr;
    always_ff @( posedge clk ) begin
        int fa, fb;
        if (rst) begin
            for(fa=0;fa<`FTQ_SIZE;fa=fa+1) begin
                buffer_branchInfo[fa].mispred = 0;
            end
        end
        else begin
            // read
            for(fa=0;fa<`BRU_NUM;fa=fa+1) begin
                read_ftqStartAddr[fa] <= buffer_fetchInfo[i_read_ftqIdx[fa]].startAddr;
                read_ftqNextAddr[fa] <= buffer_fetchInfo[i_read_ftqIdx[fa]].nextAddr;
            end

            // write by backend
            for(fa=0;fa<`BRU_NUM;fa=fa+1) begin
                if (i_backend_branchwb_vld[fa]) begin
                    buffer_branchInfo[branchwbInfo[fa].ftq_idx] <= '{
                        mispred        : branchwbInfo[fa].has_mispred,
                        taken          : branchwbInfo[fa].branch_taken,
                        fallthruOffset : branchwbInfo[fa].fallthruOffset,
                        targetAddr     : branchwbInfo[fa].target_pc,
                        branch_type    : branchwbInfo[fa].branch_type
                    };
                end
            end

            // branch wb check assert
            for (fa=0;fa<`BRU_NUM;fa=fa+1) begin
                for (fb=0; fb<`BRU_NUM; fb=fb+1) begin
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

    reg update_vld;
    BPupdateInfo_t new_updateInfo;
    wire[`XDEF] temp_fallthruAddr = buffer_fetchInfo[commit_ptr].startAddr + buffer_branchInfo[commit_ptr].fallthruOffset;
    always_ff @( posedge clk ) begin
        if (rst) begin
            update_vld <= 0;
        end
        else begin
            if (do_commit) begin
                new_updateInfo <= '{
                    startAddr : buffer_fetchInfo[commit_ptr].startAddr,
                    // generate new ftb entry
                    // TODO: optimize it
                    ftb_update : '{
                        carry        : temp_fallthruAddr[`FTB_FALLTHRU_WIDTH+1] == buffer_fetchInfo[commit_ptr].startAddr[`FTB_FALLTHRU_WIDTH+1],
                        fallthruAddr : temp_fallthruAddr[`FTB_FALLTHRU_WIDTH:1],
                        tarStat      : ftbFuncs::calcuTarStat(buffer_fetchInfo[commit_ptr].startAddr, buffer_branchInfo[commit_ptr].targetAddr),
                        targetAddr   : buffer_branchInfo[commit_ptr].targetAddr[`FTB_TARGET_WIDTH:1],
                        branch_type  : buffer_branchInfo[commit_ptr].branch_type,
                        counter      : ftbFuncs::counterUpdate(buffer_metaInfo[commit_ptr].ftb_counter, buffer_branchInfo[commit_ptr].taken)
                    }
                };
            end
            update_vld <= do_commit && need_update_ftb;
        end
    end

    assign o_bpu_update = update_vld;
    assign o_BPUupdateInfo = new_updateInfo;


/****************************************************************************************************/
// send request to icache
/****************************************************************************************************/

    assign o_icache_fetch_req = do_fetch;
    assign o_icache_fetch_ftqIdx = fetch_ptr;
    assign o_icache_fetchInfo = '{
        startAddr : buffer_fetchInfo[fetch_ptr].startAddr,
        fetchBlock_size : buffer_fetchInfo[fetch_ptr].endAddr - buffer_fetchInfo[fetch_ptr].startAddr
    };

    `ASSERT(do_fetch ? (buffer_fetchInfo[fetch_ptr].endAddr > buffer_fetchInfo[fetch_ptr].startAddr) : 1);
    `ASSERT(do_fetch ? (buffer_fetchInfo[fetch_ptr].endAddr - buffer_fetchInfo[fetch_ptr].startAddr <= 64) : 1);


endmodule




