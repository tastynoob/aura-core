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


module ROB(
    input wire clk,
    input wire rst,

    // from/to csr
    input csr_in_pack_t i_csr_pack,

    //from dispatch insert, enque
    output wire o_can_enq,
    input wire i_enq_vld,
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_req,
    input ROBEntry_t i_new_entry[`RENAME_WIDTH],
    input ftqOffset_t i_new_entry_ftqOffset[`RENAME_WIDTH],//ftqOffset separate from rob
    output robIdx_t o_alloc_robIdx[`RENAME_WIDTH],

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

    // used for trap
    // from decoupled frontend
    // read from the last commited insts
    output ftqIdx_t o_ftq_idx,
    input wire[`XDEF] i_ftq_startAddress,

    //to decoupled frontend
    output wire o_branch_commit_vld,
    output ftqIdx_t o_committed_ftq_idx,// set the ftq commit_ptr to this

    // pipeline control
    output wire o_squash_vld,
    output squashInfo_t o_squashInfo
);
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
    ftqOffset_t reordered_ftqOffset[`RENAME_WIDTH];
    reorder
    #(
        .dtype ( ftqOffset_t    ),
        .NUM   ( `RENAME_WIDTH  )
    )
    u_reorder(
        .i_data_vld      ( i_enq_req             ),
        .i_datas         ( i_new_entry_ftqOffset ),
        .o_data_vld      (),
        .o_reorder_datas ( reordered_ftqOffset   )
    );
    always_ff @( posedge clk ) begin
        for(j=0;j<`RENAME_WIDTH;j=j+1) begin
            if (enq_vld[j]) begin
                ftqOffset_buffer[enq_idx[i]] <= reordered_ftqOffset[i];
            end
        end
    end





/****************************************************************************************************/
// commit to decoupled and rename
//
/****************************************************************************************************/
    reg[`WDEF(`COMMIT_WIDTH)] renameCommit_vld;
    renameCommitInfo_t renameCommitInfo[`COMMIT_WIDTH];
    // only can commit one fetchblock
    reg branchCommit_vld;
    ftqIdx_t committed_ftq_idx;

    always_ff @( posedge clk ) begin : blockName
        if (rst) begin
            renameCommit_vld <= 0;
            branchCommit_vld <= 0;
        end
        else begin
            if (canCommit_vld[0]) begin
                branchCommit_vld <= 1;
            end
            else begin
                branchCommit_vld <= 0;
            end
        end
    end


/****************************************************************************************************/
// branch process
// get the oldest mispred branch
// writeback and update in one cycle
// DESIGN: acyually we no need to limit the maximum of fetchBlock
// branch write back to rob and ftq at the same time
// rob need to get the oldest mispred branch to squash
// ftq has the same number of writeback as the number of bju
// send the last committed ftqIdx to ftq to commit
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
    generate
        // 0 | 0 | 1(has_mispred) | 1
        wire[`WDEF(`COMMIT_WIDTH)] temp_0;
        for(i=`COMMIT_WIDTH-1;i>=0;i=i-1) begin:gen_for
            if (i==`COMMIT_WIDTH-1) begin :gen_if
                assign temp_0[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
            end
            else begin:gen_else
                assign temp_0[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx) || temp_0[i+1];
            end
        end
    endgenerate
    assign has_mispred = temp_0[0] && bmhr.mispred;


/****************************************************************************************************/
// except process
// get the oldest exception
//
/****************************************************************************************************/

    // we need to store the oldest inst whicth has excepted
    // exception handle register
    except_handle ehr;
    always_ff @( posedge clk ) begin
        if (clk) begin
            ehr.has_except <= 0;
        end
        else begin
            if (i_branchwb_vld && i_exceptwb_info.has_except) begin
                if ((ehr.rob_idx.flipped == i_exceptwb_info.rob_idx.flipped) ? (i_branchwb_info.rob_idx.idx < ehr.rob_idx.idx) : (i_branchwb_info.rob_idx.idx > ehr.rob_idx.idx)) begin
                    ehr <= '{
                        rob_idx:i_exceptwb_info.rob_idx,
                        has_except:i_exceptwb_info.has_except,
                        except_type:i_exceptwb_info.except_type
                    };
                end
            end
        end
    end
    generate
        // normal:
        // 1 | 1 | 1 | 1
        // 0 | 0(has_except) | 1 | 1
        wire[`WDEF(`COMMIT_WIDTH)] temp_1;
        // 0 | 1(has_except) | 0 | 0
        wire[`WDEF(`COMMIT_WIDTH)] temp_2;
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            if (i==0) begin :gen_if
                assign temp_1[i] = willCommit_vld[i] && (willCommit_idx[i] != bmhr.rob_idx.idx);
            end
            else begin:gen_else
                assign temp_1[i] = willCommit_vld[i] && (willCommit_idx[i] != bmhr.rob_idx.idx) && temp_1[i+1];
            end
            assign temp_2[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
        end
    endgenerate
    assign has_except = (|temp_2) && ehr.has_except;

    always_comb begin
        for(j=0;j<`COMMIT_WIDTH;j=j+1) begin
            if(canCommit_vld[j]) begin
                last_committed_inst = willCommit_data[j];
                last_committed_rob_idx = willCommit_idx[j];
            end
        end
    end
    assign canCommit_vld = has_except ?  temp_1 : willCommit_vld;

/****************************************************************************************************/
// retire
// send sqush signal
// DESIGN: when except or interrupt, stall commit/read ftq -> compute the trap return address -> squash
// if mispred && (has_except || has_interrupt) mepc = bmhr.npc else mecp = ftq[ftq_idx[last_commit]] + offset;
// NOTE: the fetchblock start pc read from ftq, the ftqOffset read from ftqOffset_buffer
// if trap, we need one more cycle to process trap
/****************************************************************************************************/

    commit_status_t::_ status;
    wire[`XDEF] last_committed_pc;
    wire[`XDEF] trap_ret_pc;
    reg last_committed_isRVC;
    ftqOffset_t ftq_offset;
    reg squash_vld;
    squashInfo_t squashInfo;
    always_ff @( posedge clk ) begin
        if (rst) begin
            status <= commit_status_t::normal;
            commit_stall <= 0;
            squash_vld <= 0;
        end
        else begin
            // | commit and read ftq (normal) | (trapProcess) | squash
            // 0                              1               2
            if ((has_except || has_interrupt) && (status==commit_status_t::normal)) begin
                // s1: stall and read ftq;
                commit_stall <= 1;
                status <= commit_status_t::trapProcess;
                // NOTE: if has except, last_committed_inst = (excepted inst - 1)
                last_committed_isRVC <= last_committed_inst.isRVC;
                ftq_offset <= ftqOffset_buffer[last_committed_rob_idx];
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
                // if has trap: mepc = i_ftq_startAddress + ftq_offset + isRVC ? 2:4
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

    assign last_committed_pc = i_ftq_startAddress + ftq_offset;
    assign trap_ret_pc = last_committed_pc + (last_committed_isRVC ? 2:4);



endmodule
