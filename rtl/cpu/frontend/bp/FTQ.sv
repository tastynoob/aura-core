`include "frontend_define.svh"


typedef struct {
    logic[`XDEF] startAddr;
    logic[`XDEF] endAddr;
    logic[`XDEF] nextAddr;
} ftqFetchInfo_t;

typedef struct {
    logic mispred;
    logic taken;
    logic[`XDEF] fallthruAddr;
    logic[`XDEF] targetAddr;
} ftqBranchInfo_t;// branch writeback

typedef struct {
    // ftb meta
    logic hit_on_ftb;
    BranchType::_ branch_type;
    logic[`WDEF(2)] ftb_counter;
} ftqMetaInfo_t;

// DESIGN:
// when squash, the ftq[commit_ftqIdx] is mispred fetch block
module FTQ (
    input wire clk,
    input wire rst,
    input wire i_squash_vld,
    input wire i_squashInfo,

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
    input wire i_icache_fetch_rdy,
    output ftq2icacheInfo_t o_icache_fetchInfo,

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
    ftqFetchInfo_t buffer_branchInfo[`FTQ_SIZE];
    ftqMetaInfo_t buffer_metaInfo[`FTQ_SIZE];

    wire notFull = count != `FTQ_SIZE;
    assign o_ftq_rdy = notFull;

/****************************************************************************************************/
// do update for ptr
/****************************************************************************************************/
    wire do_commit = (commit_ptr != commit_ptr_thre);
    wire do_fetch = (count != 0);

    always_ff @( posedge clk ) begin
        if (rst) begin
            pred_ptr <= 0;
            fetch_ptr <= 0;
            commit_ptr <= 0;
            commit_ptr_thre <= 0;
            count <= 0;
        end
        else begin
            if (notFull) begin
                count <= count + i_pred_req - (do_commit & i_bpu_update_finished);
            end

            if (i_pred_req && notFull) begin
                pred_ptr <= (pred_ptr == `FTQ_SIZE - 1) ? 0 : pred_ptr + 1;
            end

            if (i_icache_fetch_rdy) begin
                fetch_ptr <= (fetch_ptr == `FTQ_SIZE - 1) ? 0 : fetch_ptr + 1;
            end

            if (i_commit_vld) begin
                commit_ptr_thre <= i_commit_ftqIdx;
            end
            // do commit
            if (commit_ptr != commit_ptr_thre) begin
                if (i_bpu_update_finished) begin
                    commit_ptr <= (commit_ptr == `FTQ_SIZE - 1) ? 0 : commit_ptr + 1;
                end
            end
        end
    end
/****************************************************************************************************/
// BPU insert into FTQ
/****************************************************************************************************/

always_ff @( posedge clk ) begin
    if (rst) begin
    end
    else begin
        if (i_pred_req || notFull) begin
            buffer_fetchInfo[pred_ptr] <= '{
                // TODO:
            };
        end
    end
end




/****************************************************************************************************/
// writeback from backend
/****************************************************************************************************/

    branchwbInfo_t branchwbInfo[`BRU_NUM];
    generate
        for(i=0;i<`BRU_NUM;i=i+1) begin:gen_for
            assign branchwbInfo[i] = i_backend_branchwbInfo[i];
        end
    endgenerate


    always_ff @( posedge clk ) begin
        int fa, fb;
        if (rst) begin

        end
        else begin
            // write by backend
            for(fa=0;fa<`BRU_NUM;fa=fa+1) begin
                if (i_backend_branchwb_vld[fa]) begin
                    buffer_branchInfo[branchwbInfo[fa].ftq_idx] <= '{
                        mispred:0,
                        taken:0,
                        fallthruAddr:0,
                        targetAddr:0
                    };
                end
            end

            // check assert
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
// commit ftq entry
/****************************************************************************************************/

    assign o_bpu_update = (do_commit || (i_commit_vld && (i_commit_ftqIdx != commit_ptr_thre))) && buffer[commit_ptr].has_mispred;

    assign o_BPUupdateInfo = '{
        startAddr : buffer[commit_ptr].startAddr,
        ftb_update : '{
            carry : 0,
            fallthruAddr : 0,
            tarStat : 0,
            targetAddr : 0,
            branch_type : 0,
            counter : 0
        }
    };


/****************************************************************************************************/
// send request to icache
/****************************************************************************************************/

    assign o_icache_fetch_req = do_fetch;

    assign o_icache_fetchInfo = '{
        startAddr : buffer_fetchInfo[fetch_ptr].startAddr,
        fetchBlock_size : buffer_fetchInfo[fetch_ptr].endAddr - buffer[fetch_ptr].startAddr
    };
    `ASSERT(do_fetch ? (buffer[fetch_ptr].endAddr > buffer[fetch_ptr].startAddr) : 1);
    `ASSERT(do_fetch ? (buffer[fetch_ptr].endAddr - buffer[fetch_ptr].startAddr <= 64) : 1);


endmodule




