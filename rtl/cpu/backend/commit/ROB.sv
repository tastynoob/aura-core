`include "core_define.svh"



typedef struct {
    robIdx_t rob_idx;
    logic taken;
    logic mispred;
    logic[`XDEF] pc;
    logic[`XDEF] npc;
} branch_mispred_handle;


typedef struct {
    robIdx_t rob_idx;
    logic has_except;
    rv_trap_t::exception except_type;
} except_handle;


typedef struct packed {
    robIdx_t rob_idx;
    logic[`XDEF] access_addr;
} lsu_handle;

package commit_status_t;

typedef enum logic[1:0] {
    normal,
    trapProcess
} _;

endpackage


function automatic int robIdx_compare(robIdx_t a, robIdx_t b);// is a older than b, if a==b return false
        return (a.flipped == i_rob_idx[1].flipped) ?
        (a.idx < b.idx) :
        (a.idx > b.idx);
endfunction


module ROB(
    input wire clk,
    input wire rst,

    // TODO; trap control
    // from/to csr
    input csr_in_pack_t i_csr_pack,
    output csr_out_pack_t o_csr_pack,

    // from dispatch insert, enque
    output wire o_can_enq,
    input wire i_enq_vld,
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_req,
    input wire[`WDEF(`RENAME_WIDTH)] i_insert_rob_ismv,
    input ROBEntry_t i_new_entry[`RENAME_WIDTH],
    input ftqOffset_t i_new_entry_ftqOffset[`RENAME_WIDTH],//ftqOffset separate from rob
    output robIdx_t o_alloc_robIdx[`RENAME_WIDTH],

    // exu read ftqOffset (exu read from rob)
    input wire[`WDEF($clog2(`ROB_SIZE))] i_read_ftqOffset_idx[`MISC_NUM],
    output ftqOffset_t o_read_ftqOffset_data[`MISC_NUM],


    // read by the last commited insts
    // rob read ftq_startAddress (rob read from ftq)
    output ftqIdx_t o_ftq_idx,
    input wire[`XDEF] i_ftq_startAddress,

    // write back, from exu
    // common writeback
    input wire[`WDEF(`WBPORT_NUM)] i_wb_vld,
    input commWBInfo_t i_wbInfo[`WBPORT_NUM],
    // branch writeback (branch taken or mispred)
    input wire i_branchwb_vld,
    input branchWBInfo_t i_branchwb_info,
    // except writeback
    input wire i_exceptwb_vld,
    input exceptWBInfo_t i_exceptwb_info,

    //to rename
    output wire[`WDEF(`COMMIT_WIDTH)] o_rename_commit,
    output renameCommitInfo_t o_rename_commitInfo[`COMMIT_WIDTH],

    //to decoupled frontend, notify which inst was committed
    output wire o_branch_commit_vld,
    output ftqIdx_t o_committed_ftq_idx,// set the ftq commit_ptr to this(last committed ftqIdx)

    // we need to notify which store was committed
    output wire o_commit_vld,
    output wire[`WDEF($clog2(`ROB_SIZE))] o_committed_rob_idx,

    // pipeline control
    output wire o_squash_vld,
    output squashInfo_t o_squashInfo
);
    `ORDER_CHECK(i_enq_req);
    genvar i;
    integer j;


    reg commit_stall;
    wire[`WDEF(`COMMIT_WIDTH)] canCommit_vld;
    wire[`WDEF(`COMMIT_WIDTH)] willCommit_vld;
    wire[`WDEF($clog2(`ROB_SIZE))] willCommit_idx[`COMMIT_WIDTH];
    ROBEntry_t willCommit_data[`COMMIT_WIDTH];
    wire has_mispred;
    wire has_except;
    wire has_interrupt;

    // if has except, last_committed_inst = (excepted inst - 1)
    ROBEntry_t last_committed_inst;
    // if has except last_committed_rob_idx = (excepted inst - 1)
    wire[`WDEF($clog2(`ROB_SIZE))] last_committed_rob_idx;

    wire ptr_flipped[`RENAME_WIDTH];
    wire[`WDEF($clog2(`ROB_SIZE))] alloc_idx[`RENAME_WIDTH];
    generate
        for(i=0;i<`RENAME_WIDTH;i=i+1) begin:gen_for
            assign o_alloc_robIdx[i] = '{
                flipped : ptr_flipped[i],
                idx     : alloc_idx[i]
            };
        end
    endgenerate
    wire[`WDEF($clog2(`ROB_SIZE))] clear_idx[`COMMIT_WIDTH];
    generate
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            assign clear_idx[i] = i_wbInfo[i].rob_idx.idx;
        end
    endgenerate
    // NOTE: if commited insts has multi fetchblock ends
    // we need to stall, only commit first one fetchblock
    ftqOffset_t ftqOffset_buffer[`ROB_SIZE];
    wire[`WDEF(`RENAME_WIDTH)] enq_vld;
    wire[`WDEF($clog2(`ROB_SIZE))] enq_idx[`RENAME_WIDTH];
    dataQue
    #(
        .DEPTH          ( `ROB_SIZE     ),
        .INPORT_NUM     ( `RENAME_WIDTH ),
        .READPORT_NUM   ( 0             ),
        .CLEARPORT_NUM  ( `WBPORT_NUM   ),
        .WBPORT_NUM     ( 0             ),
        .COMMIT_WID     ( `COMMIT_WIDTH ),
        .dtype          ( ROBEntry_t    ),
        .ISROB          ( 1             )
    )
    u_dataQue(
        .clk              ( clk             ),
        .rst              ( rst             ),
        .i_stall          ( commit_stall    ),

        .o_can_enq        ( o_can_enq       ),
        .i_enq_vld        ( i_enq_vld       ),
        .i_enq_req        ( i_enq_req       ),
        .i_enq_req_mark_finished ( i_insert_rob_ismv ),
        .i_enq_data       ( i_new_entry     ),
        .o_ptr_flipped    ( ptr_flipped     ),
        .o_alloc_id       ( alloc_idx       ),
        .o_enq_vld        ( enq_vld         ),
        .o_enq_idx        ( enq_idx         ),
        // inst finished
        .i_clear_vld      ( i_wb_vld      ),
        .i_clear_dqIdx    ( clear_idx    ),

        .o_willClear_vld  ( willCommit_vld  ),
        .o_willClear_idx  ( willCommit_idx  ),
        .o_willClear_data ( willCommit_data )
    );

    always_ff @( posedge clk ) begin
        for(j=0;j<`RENAME_WIDTH;j=j+1) begin
            // write ftqOffset
            if (enq_vld[j]) begin
                ftqOffset_buffer[enq_idx[i]] <= i_new_entry_ftqOffset[i];
            end
        end
    end

    generate
        // read from exu
        for(i=0;i<`MISC_NUM;i=i+1) begin:gen_for
            assign o_read_ftqOffset_data[i] = ftqOffset_buffer[i_read_ftqOffset_idx[i]];
        end
    endgenerate


/****************************************************************************************************/
// commit, update the ftq commit_ptr, rename status, storeQue
// decoupled front commit can be one cycle later than rob commit (actually both in one cycle)
// rename commit, storeQue commit and rob commit must in one cycle
/****************************************************************************************************/


    assign o_branch_commit_vld = canCommit_vld[0];
    assign o_committed_ftq_idx = last_committed_inst.ftq_idx;
    // TODO: we may need to improve rename method
    // rename rob commit -> physical register used buffer
    assign o_rename_commit = canCommit_vld;
    generate
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            assign o_rename_commitInfo[i] = '{
                ismv:willCommit_data[i].ismv,
                has_rd:willCommit_data[i].has_rd,
                ilrd_idx:willCommit_data[i].ilrd_idx,
                iprd_idx:willCommit_data[i].iprd_idx,
                prev_iprd_idx:willCommit_data[i].prev_iprd_idx
            };
        end
    endgenerate

    assign o_commit_vld = canCommit_vld[0];
    assign o_committed_rob_idx = last_committed_rob_idx;



/****************************************************************************************************/
// branch process
// get the oldest mispred branch
// writeback and update in one cycle
// DESIGN: acyually we no need to limit the maximum of fetchBlock
// branch write back to rob and ftq at the same time
// rob need to get the oldest mispred branch to squash
// ftq has the same number of writeback as the number of bju
// send the last committed ftqIdx to ftq to commit
// NOTE: if (mispred | except | normal | normal) we do except first
// if (normal | except | mispred | normal) we do mispred first
// if (normal | mispred | normal | normal) and has interrupt, we need assign mepc to mispre actuallt target
/****************************************************************************************************/

    // we need to store the oldest branch which was mispred
    // branch mispred handle register
    branch_mispred_handle bmhr;
    always_ff @( posedge clk ) begin
        if (rst) begin
            bmhr.mispred <= 0;
        end
        else begin
            if (i_branchwb_vld && i_branchwb_info.has_mispred) begin
                if ((bmhr.rob_idx.flipped == i_branchwb_info.rob_idx.flipped) ? (i_branchwb_info.rob_idx.idx < bmhr.rob_idx.idx) : (i_branchwb_info.rob_idx.idx > bmhr.rob_idx.idx)) begin
                    bmhr <= '{
                        rob_idx:i_branchwb_info.rob_idx,
                        taken:i_branchwb_info.branch_taken,
                        mispred:i_branchwb_info.has_mispred,
                        pc:i_branchwb_info.branch_pc,
                        npc:i_branchwb_info.branch_npc
                    };
                end
            end
        end
    end

    wire[`WDEF(`COMMIT_WIDTH)] temp_0;// 0 | 0 | 1(has_mispred) | 1
    wire[`WDEF(`COMMIT_WIDTH)] temp_1;// 0 | 0 | 1(has_mispred) | 0
    generate

        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            if (i==0) begin:gen_if
                assign temp_0[i] = willCommit_vld[i];
            end
            else begin:gen_else
                assign temp_0[i] = willCommit_vld[i] && (willCommit_idx[i-1] != bmhr.rob_idx.idx) && temp_0[i-1];
            end
            assign temp_1[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
        end
        `ASSERT(count_one(temp_1) <= 1);
    endgenerate
    assign has_mispred = (|temp_1) && bmhr.mispred;


/****************************************************************************************************/
// trap process
// get the oldest exception
// if :
// mispred: 0 | 0 | 1 | 0 (temp_1)
// except:  0 | 1 | 0 | 0 (temp_3)
// ignore except
// if :
// mispred: 0 | 1 | 0 | 0 (temp_1)
// except:  0 | 0 | 1 | 0 (temp_3)
// has except
// if :
// mispred: 0 | 0 | 1 | 0 (temp_1)
// except:  0 | 0 | 1 | 0 (temp_3)
// assert(false)
/****************************************************************************************************/

    // we need to store the oldest inst whicth has excepted
    // exception handle register
    except_handle ehr;
    always_ff @( posedge clk ) begin
        if (clk) begin
            ehr.has_except <= 0;
        end
        else begin
            if (i_exceptwb_vld) begin
                if ((ehr.rob_idx.flipped == i_exceptwb_info.rob_idx.flipped) ? (i_exceptwb_info.rob_idx.idx < ehr.rob_idx.idx) : (i_exceptwb_info.rob_idx.idx > ehr.rob_idx.idx)) begin
                    ehr <= '{
                        rob_idx:i_exceptwb_info.rob_idx,
                        has_except:1, // if write except, it must be true
                        except_type:i_exceptwb_info.except_type
                    };
                end
            end
        end
    end
    generate
        wire[`WDEF(`COMMIT_WIDTH)] temp_2;// 0 | 0(has_except) | 1 | 1
        wire[`WDEF(`COMMIT_WIDTH)] temp_3;// 0 | 1(has_except) | 0 | 0
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            if (i==0) begin :gen_if
                assign temp_2[i] = willCommit_vld[i] && (willCommit_idx[i] != ehr.rob_idx.idx);
            end
            else begin:gen_else
                assign temp_2[i] = willCommit_vld[i] && (willCommit_idx[i] != ehr.rob_idx.idx) && temp_2[i-1];
            end
            assign temp_3[i] = willCommit_vld[i] && (willCommit_idx[i] == ehr.rob_idx.idx);
        end
        `ASSERT(count_one(temp_3) <= 1);
    endgenerate
    // mispred robIdx > except robIdx
    assign has_except = (|temp_3) && ehr.has_except && (temp_3 < temp_1);
    `ASSERT ((temp_3 != temp_1) || ((temp_3 == 0) && (temp_1 == 0)));

    assign canCommit_vld = has_except ? temp_2 : temp_0;
    assign o_ftq_idx = last_committed_ins.ftq_idx;

    always_comb begin
        for(j=0;j<`COMMIT_WIDTH;j=j+1) begin
            if(canCommit_vld[j]) begin
                last_committed_inst = willCommit_data[j];
                last_committed_rob_idx = willCommit_idx[j];
            end
        end
    end

/****************************************************************************************************/
// retire
// send sqush signal
// DESIGN: when except or interrupt, stall commit/read ftq -> compute the trap return address -> squash
// if mispred && (has_except || has_interrupt) mepc = bmhr.npc else mecp = ftq[ftq_idx[last_commit]] + offset;
// NOTE: the fetchblock start pc read from ftq, the ftqOffset read from ftqOffset_buffer
// if trap, we need one more cycle to process trap
// trap process and csr update in one cycle
/****************************************************************************************************/

    commit_status_t::_ status;
    wire[`XDEF] last_committed_pc;
    wire[`XDEF] trap_ret_pc;
    reg last_committed_isRVC;
    ftqOffset_t ftqOffset;
    reg squash_vld;
    squashInfo_t squashInfo;
    always_ff @( posedge clk ) begin
        if (rst) begin
            status <= commit_status_t::normal;
            commit_stall <= 0;
            squash_vld <= 0;
        end
        else begin
            // pipe: (| commit and read ftq (normal) | (trapProcess) | squash)
            // 0                              1               2
            if ((has_except || has_interrupt) && (status==commit_status_t::normal)) begin
                // s1: stall and read ftq;
                commit_stall <= 1;
                status <= commit_status_t::trapProcess;
                // NOTE: if has except, last_committed_inst = (excepted inst - 1)
                last_committed_isRVC <= last_committed_inst.isRVC;
                // read from rob
                ftqOffset <= ftqOffset_buffer[last_committed_rob_idx];
            end
            else if (status == commit_status_t::trapProcess) begin
                // s2: compute the squashInfo
                // compute the trap return address
                squash_vld <= true;
                squashInfo.dueToBranch <= 0;
                squashInfo.branch_taken <= 0;
                //// TODO: trap address select
                squashInfo.arch_pc <= has_interrupt ? i_csr_pack.tvec + (0) : i_csr_pack.tvec;
                // TODO:
                // if has interrupt, we must wait for a safe cycle
                // if has trap: mepc = has_mispred ? bmhr.npc : i_ftq_startAddress + ftqOffset + isRVC ? 2:4
                // if has interrupt and squash : wait for squash finish
                // if has interrupt and rob is empty: mepc = last inst pc + ismv 2:4
            end
            else if (has_mispred) begin
                squash_vld <= true;
                squashInfo.dueToBranch <= has_mispred;
                squashInfo.branch_taken <= bmhr.taken;
                squashInfo.arch_pc <= bmhr.npc;
            end
        end
    end

    assign o_squash_vld = squash_vld;
    assign o_squashInfo = squashInfo;

    assign last_committed_pc = i_ftq_startAddress + ftqOffset;
    assign trap_ret_pc = last_committed_pc + (last_committed_isRVC ? 2:4);



endmodule
