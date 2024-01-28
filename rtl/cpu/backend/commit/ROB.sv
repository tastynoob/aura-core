`include "core_define.svh"
`include "funcs.svh"
`include "dpic.svh"

import "DPI-C" function void arch_commitInst(
    uint64_t dst_type,
    uint64_t logic_idx,
    uint64_t physic_idx,
    uint64_t instmeta_ptr
);

import "DPI-C" function void arch_commit_except();

import "DPI-C" function void squash_pipe(uint64_t isMispred);
import "DPI-C" function void cycle_step();
import "DPI-C" function void commit_idle(uint64_t c);

const logic[`WDEF(2)] SQUASH_NULL = 0;
const logic[`WDEF(2)] SQUASH_MISPRED = 1;
const logic[`WDEF(2)] SQUASH_EXCEPT = 2;


typedef struct {
    robIdx_t rob_idx;
    logic[`WDEF(2)] squash_type;
    // branch
    logic branch_taken;
    logic [`XDEF] npc;
    // trap
    rv_trap_t::exception except_type;
} squash_handle;

package commit_status_t;

typedef enum logic[1:0] {
    normal,
    trapProcess
} _;

endpackage



// DESIGN: branch writeback to ftq and rob
// when write rob, we need to select the oldest branch which is mispred
module ROB(
    input wire clk,
    input wire rst,

    // TODO; trap control
    // from/to csr
    input csr_in_pack_t i_csr_pack,
    output trap_pack_t o_trap_pack,
    syscall_if.s if_syscall,

    // from dispatch insert, enque
    output wire o_can_enq,
    input wire i_enq_vld,
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_req,
    input wire[`WDEF(`RENAME_WIDTH)] i_insert_rob_ismv,
    input ROBEntry_t i_new_entry[`RENAME_WIDTH],
    input ftqOffset_t i_new_entry_ftqOffset[`RENAME_WIDTH],//ftqOffset separate from rob
    output robIdx_t o_alloc_robIdx[`RENAME_WIDTH],

    // exu read ftqOffset (exu read from rob)
    input wire[`WDEF($clog2(`ROB_SIZE))] i_read_ftqOffset_idx[`BRU_NUM],
    output ftqOffset_t o_read_ftqOffset_data[`BRU_NUM],

    // write back, from exu
    // common writeback
    input wire[`WDEF(`WBPORT_NUM)] i_fu_finished,
    input comwbInfo_t i_comwbInfo[`WBPORT_NUM],
    // branch writeback
    input wire i_branchwb_vld,
    input branchwbInfo_t i_branchwb_info,
    // except writeback
    input wire i_exceptwb_vld,
    input exceptwbInfo_t i_exceptwb_info,

    // we need to notify commit ptr
    output wire o_commit_vld,
    output wire[`WDEF($clog2(`ROB_SIZE))] o_commit_rob_idx,

    output wire o_commit_ftq_vld,
    output ftqIdx_t o_commit_ftq_idx,// set the ftq commit_ptr_thre to this

    // to rename
    output wire[`WDEF(`COMMIT_WIDTH)] o_rename_commit,
    output renameCommitInfo_t o_rename_commitInfo[`COMMIT_WIDTH],

    // read by the last commited insts
    // rob read ftq_startAddress (rob read from ftq)
    output wire o_read_ftq_Vld,
    output ftqIdx_t o_read_ftqIdx,
    input wire[`XDEF] i_read_ftqStartAddr,

    // pipeline control
    output wire o_can_dispatch_serialize,
    output wire o_commit_serialized_inst,
    output wire o_squash_vld,
    output squashInfo_t o_squashInfo
);
    `ORDER_CHECK(i_enq_req);
    genvar i;

    reg squash_vld;
    squashInfo_t squashInfo;
    reg commit_stall;
    wire[`WDEF(`COMMIT_WIDTH)] canCommit_vld;
    wire[`WDEF(`COMMIT_WIDTH)] willCommit_vld;
    wire[`WDEF($clog2(`ROB_SIZE))] willCommit_idx[`COMMIT_WIDTH];
    ROBEntry_t willCommit_data[`COMMIT_WIDTH];
    wire has_mispred;
    wire has_except;
    wire has_interrupt=0;//TODO:interrupt

    // if has except, commit_end_inst = (excepted inst - 1)
    ROBEntry_t commit_end_inst;
    // if has except prev_commit_rob_idx = (excepted inst - 1)
    logic[`WDEF($clog2(`ROB_SIZE))] prev_commit_rob_idx;

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
    wire[`WDEF($clog2(`ROB_SIZE))] finished_robIdx[`WBPORT_NUM];
    generate
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            assign finished_robIdx[i] = i_comwbInfo[i].rob_idx.idx;
        end
    endgenerate
    // NOTE: if commited insts has multi fetchblock ends
    // we need to stall, only commit first one fetchblock
    ftqOffset_t ftqOffset_buffer[`ROB_SIZE];
    wire dataQue_empty;
    wire[`WDEF(`RENAME_WIDTH)] enq_vld;
    wire[`WDEF($clog2(`ROB_SIZE))] enq_idx[`RENAME_WIDTH];
    dataQue
    #(
        .DEPTH          ( `ROB_SIZE     ),
        .INPORT_NUM     ( `RENAME_WIDTH ),
        .READPORT_NUM   ( 0             ),
        .CLEARPORT_NUM  ( `WBPORT_NUM   ),
        .COMMIT_WID     ( `COMMIT_WIDTH ),
        .dtype          ( ROBEntry_t    ),
        .ISROB          ( 1             )
    )
    u_dataQue(
        .clk              ( clk             ),
        .rst              ( rst || squash_vld ),
        .i_stall          ( commit_stall    ),
        .o_empty          ( dataQue_empty   ),

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
        .i_clear_vld      ( i_fu_finished      ),
        .i_clear_dqIdx    ( finished_robIdx    ),

        .o_willClear_vld  ( willCommit_vld  ),
        .o_willClear_idx  ( willCommit_idx  ),
        .o_willClear_data ( willCommit_data )
    );

    ftqOffset_t read_ftqOffset_data[`BRU_NUM];
    always_ff @( posedge clk ) begin
        int fj;
        for(fj=0;fj<`RENAME_WIDTH;fj=fj+1) begin
            // write ftqOffset
            if (enq_vld[fj]) begin
                ftqOffset_buffer[enq_idx[fj]] <= i_new_entry_ftqOffset[fj];
            end
        end
        for (fj=0;fj<`BRU_NUM;fj=fj+1) begin
            read_ftqOffset_data[fj] <= ftqOffset_buffer[i_read_ftqOffset_idx[fj]];
        end
    end

    generate
        // read from exu
        for(i=0;i<`BRU_NUM;i=i+1) begin:gen_for
            assign o_read_ftqOffset_data[i] = read_ftqOffset_data[i];
        end
    endgenerate


/****************************************************************************************************/
// commit, update the ftq commit_ptr, rename status, storeQue
// decoupled front commit can be one cycle later than rob commit (actually both in one cycle)
// rename commit, storeQue commit and rob commit must in one cycle
/****************************************************************************************************/
    generate
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            assign o_rename_commitInfo[i] = '{
                ismv        : willCommit_data[i].ismv,
                has_rd      : willCommit_data[i].has_rd,
                ilrd_idx    : willCommit_data[i].ilrd_idx,
                iprd_idx    : willCommit_data[i].iprd_idx,
                prev_iprd_idx : willCommit_data[i].prev_iprd_idx
            };
        end
    endgenerate

    assign o_commit_vld = canCommit_vld[0];
    assign o_commit_rob_idx = prev_commit_rob_idx;

    assign o_commit_ftq_vld = o_commit_vld;
    assign o_commit_ftq_idx = has_mispred ? (commit_end_inst.ftq_idx == `FTQ_SIZE-1 ? 0 : commit_end_inst.ftq_idx + 1) : commit_end_inst.ftq_idx;

    assign o_rename_commit = squash_vld ? 0 : canCommit_vld;
/****************************************************************************************************/
// squash reason process
// if has mispred, the mispred inst can be committed
// if has except, the except inst can not be committed
/****************************************************************************************************/

    squash_handle shr;
    always_ff @( posedge clk ) begin
        if (rst || squash_vld) begin
            shr.squash_type <= SQUASH_NULL;
        end
        else begin
            if (if_syscall.mret || if_syscall.sret) begin
                shr.squash_type <= SQUASH_MISPRED;
                shr.branch_taken <= 0;
                shr.npc <= if_syscall.npc;
                shr.rob_idx <= if_syscall.rob_idx;
                assert (willCommit_idx[0] == if_syscall.rob_idx.idx);
            end
            else if ((i_exceptwb_vld && ((i_branchwb_vld && i_branchwb_info.has_mispred) ? i_exceptwb_info.rob_idx <= i_branchwb_info.rob_idx : 1))) begin
                if ((i_exceptwb_info.rob_idx <= shr.rob_idx) || (shr.squash_type == SQUASH_NULL)) begin
                    shr.squash_type <= SQUASH_EXCEPT;
                    shr.except_type <= i_exceptwb_info.except_type;
                    shr.rob_idx <= i_exceptwb_info.rob_idx;
                end
            end
            else if (i_branchwb_vld && i_branchwb_info.has_mispred) begin
                if ((i_branchwb_info.rob_idx <= shr.rob_idx) || (shr.squash_type == SQUASH_NULL)) begin
                    shr.squash_type <= SQUASH_MISPRED;
                    shr.branch_taken <= i_branchwb_info.branch_taken;
                    shr.npc <= i_branchwb_info.branch_npc;
                    shr.rob_idx <= i_branchwb_info.rob_idx;
                end
            end
        end
    end
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(`COMMIT_WIDTH)] shr_match_vec;
    wire[`WDEF(`COMMIT_WIDTH)] temp_0;// which inst can be committed
    wire[`WDEF(`COMMIT_WIDTH)] temp_1;// one hot: which one is the shr handled
    generate

        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            assign shr_match_vec[i] = willCommit_idx[i] == shr.rob_idx.idx;
            if (i==0) begin:gen_if
                assign temp_0[i] = willCommit_vld[i] && !((shr.squash_type==SQUASH_EXCEPT) && shr_match_vec[i]);
            end
            else begin:gen_else
                assign temp_0[i] = willCommit_vld[i] && temp_0[i-1] && !((shr.squash_type==SQUASH_MISPRED) && shr_match_vec[i-1]);
            end
            assign temp_1[i] = willCommit_vld[i] && shr_match_vec[i] && (shr.squash_type != SQUASH_NULL);
        end
        `ASSERT(count_one(temp_1) <= 1);
    endgenerate

    wire[`WDEF(`COMMIT_WIDTH)] except_vec = (shr.squash_type==SQUASH_EXCEPT) ? temp_1 : 0;
    assign has_except = (shr.squash_type==SQUASH_EXCEPT) && (|temp_1);
    assign has_mispred = (shr.squash_type==SQUASH_MISPRED) && (|temp_1);

/****************************************************************************************************/

    assign canCommit_vld = temp_0;

    robIdx_t except_robIdx;
    always_comb begin
        int ca;
        commit_end_inst = willCommit_data[0];
        prev_commit_rob_idx = willCommit_idx[0];

        o_read_ftqIdx = willCommit_data[0].ftq_idx;
        except_robIdx = willCommit_idx[0];
        for(ca=0;ca<`COMMIT_WIDTH;ca=ca+1) begin
            if(canCommit_vld[ca]) begin
                commit_end_inst = willCommit_data[ca];
                prev_commit_rob_idx = willCommit_idx[ca];
            end
            if (except_vec[ca]) begin
                o_read_ftqIdx = willCommit_data[ca].ftq_idx;
                except_robIdx = willCommit_idx[ca];
            end
        end
    end

/****************************************************************************************************/
// retire
// send sqush signal
// DESIGN: when except or interrupt, stall commit/read ftq -> compute the trap return address -> squash
// if mispred && (has_except || has_interrupt) mepc = shr.npc else mecp = ftq[ftq_idx[last_commit]] + offset;
// NOTE: the fetchblock start pc read from ftq, the ftqOffset read from ftqOffset_buffer
// if trap, we need one more cycle to process trap
// trap process and csr update in one cycle
/****************************************************************************************************/

    commit_status_t::_ status;
    wire[`XDEF] last_commit_pc;
    wire[`XDEF] trap_ret_pc;
    reg last_commit_isRVC;
    ftqOffset_t ftqOffset;
    reg do_except;
    always_ff @( posedge clk ) begin
        if (rst || squash_vld) begin
            status <= commit_status_t::normal;
            commit_stall <= 0;
            squash_vld <= 0;
            do_except <= 0;
        end
        else begin
            // pipe: (| commit and read ftq (normal) | (trapProcess) | squash)
            // 0                              1               2
            if ((has_except || has_interrupt) && (status==commit_status_t::normal)) begin
                // s1: stall and read ftq;
                do_except <= 1;
                commit_stall <= 1;
                status <= commit_status_t::trapProcess;
                // NOTE: if has except, commit_end_inst = (excepted inst - 1)
                last_commit_isRVC <= commit_end_inst.isRVC;
                // read from rob
                ftqOffset <= ftqOffset_buffer[except_robIdx.idx];
            end
            else if (status == commit_status_t::trapProcess) begin
                // s2: compute the squashInfo
                // compute the trap return address
                do_except <= 0;
                squash_vld <= 1;
                squashInfo.dueToBranch <= 0;
                squashInfo.dueToViolation <= 0;
                squashInfo.branch_taken <= 0;
                //// TODO: trap address select
                squashInfo.arch_pc <= (has_interrupt ? (i_csr_pack.tvec + (0)) : i_csr_pack.tvec);
                // TODO:
                // if has interrupt, we must wait for a safe cycle
                // if has trap: mepc = has_mispred ? shr.npc : i_read_ftqStartAddr + ftqOffset + isRVC ? 2:4
                // if has interrupt and squash : wait for squash finish
                // if has interrupt and rob is empty: mepc = last inst pc + ismv 2:4
            end
            else if (has_mispred) begin
                squash_pipe(1);
                squash_vld <= 1;
                squashInfo.dueToBranch <= has_mispred;
                squashInfo.dueToViolation <= 0;
                squashInfo.branch_taken <= shr.branch_taken;
                squashInfo.arch_pc <= shr.npc;
            end
        end
    end

    assign o_read_ftq_Vld = (has_except || has_interrupt);

    // top inst is serialized and not commit
    assign o_can_dispatch_serialize = ((!canCommit_vld[0]) && (!dataQue_empty) && willCommit_data[0].serialized);
    // top inst is serialized and commit
    assign o_commit_serialized_inst = (canCommit_vld[0] && willCommit_data[0].serialized);
    assign o_squash_vld = squash_vld;
    assign o_squashInfo = squashInfo;

    assign last_commit_pc = i_read_ftqStartAddr + ftqOffset;
    assign trap_ret_pc = last_commit_pc + (last_commit_isRVC ? 2:4);

    assign o_trap_pack = '{
        has_trap : do_except,
        epc      : last_commit_pc,
        cause    : has_interrupt ? 0 :
                   {{`XLEN - `TRAPCODE_WIDTH{1'b0}}, shr.except_type},
        tval     : 0
    };

    // for debug
    longint unsigned cycle_count;
    longint unsigned lastCommitCycle;
    int AAA_committedInst;
    always_ff @(posedge clk) begin
        int fa;
        cycle_step();
        if (rst) begin
            cycle_count <= 0;
            lastCommitCycle <= 0;
            AAA_committedInst <= 0;
        end
        else if ((!squash_vld) && (!commit_stall)) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count - lastCommitCycle > 100) begin
                assert(false); // cpu stucked
            end

            AAA_committedInst <= AAA_committedInst + funcs::count_one(canCommit_vld);
            for (fa =0; fa <`COMMIT_WIDTH; fa=fa+1) begin
                if (canCommit_vld[fa]) begin
                    lastCommitCycle <= cycle_count;
                    arch_commitInst(
                        0, // dest type
                        willCommit_data[fa].ilrd_idx,
                        willCommit_data[fa].iprd_idx,
                        willCommit_data[fa].instmeta
                    );
                end
                if (except_vec[fa]) begin
                    if ((shr.except_type == rv_trap_t::breakpoint) ||
                        (shr.except_type >= rv_trap_t::ucall && shr.except_type <= rv_trap_t::mcall)) begin
                        // still difftest ecall
                        arch_commitInst(
                            0, // dest type
                            willCommit_data[fa].ilrd_idx,
                            willCommit_data[fa].iprd_idx,
                            willCommit_data[fa].instmeta
                        );
                    end
                    else begin
                        arch_commit_except();
                    end
                end
            end
        end
        if (!(canCommit_vld[0])) begin
            commit_idle(1);
        end
    end

    // used for debug
    wire[`WDEF(`RENAME_WIDTH)] AAA_inserte_vec = (o_can_enq && i_enq_vld) ? i_enq_req : 0;

    wire[`WDEF(`RENAME_WIDTH)] AAA_insert_ismv_nop = (o_can_enq && i_enq_vld) ? i_insert_rob_ismv & i_enq_req : 0;

    wire[`WDEF(`WBPORT_NUM)] AAA_fu_finished_vec = i_fu_finished;

    wire[`WDEF(`COMMIT_WIDTH)] AAA_can_commit_vec = canCommit_vld;


endmodule
