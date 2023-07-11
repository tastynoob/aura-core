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


module ROB(
    input wire clk,
    input wire rst,

    //from dispatch insert
    output wire[`WDEF(`RENAME_WIDTH)] o_can_enq,
    input wire[`WDEF(`RENAME_WIDTH)] i_insert,
    input ROBEntry_t i_new_entry[`RENAME_WIDTH],
    output robIdx_t o_alloc_robIdx[`RENAME_WIDTH],

    //write back, from exu
    // common writeback
    input wire[`WDEF(`WBPORT_NUM - `MISC_NUM)] i_wb_vld,
    input commWBInfo_t i_wbInfo[`WBPORT_NUM - `MISC_NUM],
    // branch writeback (branch taken or mispred)
    input wire i_branchwb_vld,
    input branchWBInfo_t i_branchwb_info,
    // except writeback
    input wire i_exceptwb_vld,
    input exceptWBInfo_t i_exceptwb_info,

    //to rename
    output wire[`WDEF(`COMMIT_WIDTH)] o_rename_commit,
    output renameCommitInfo_t o_rename_commitInfo[`COMMIT_WIDTH],

    //to decoupled frontend
    output wire o_branch_commit,
    output branchCommitInfo_t o_branch_commitInfo,

    // pipeline control
    output wire o_squash_vld,
    output squashInfo_t o_squashInfo
);
    genvar i;
    integer j;
    wire[`WDEF(`COMMIT_WIDTH)] willCommit_vld;
    wire[`WDEF($clog2(`ROB_SIZE))] willCommit_idx[`COMMIT_WIDTH];
    ROBEntry_t willCommit_data[`COMMIT_WIDTH];
    wire has_mispred;
    wire has_except;
    wire has_interrupt;
    wire[`XDEF] trap_ret_pc; // used for except ret(mepc)

    // arch pc
    reg[`XDEF] arch_pc;
    wire[`XDEF] alloc_pc[`COMMIT_WIDTH + 1];

    always_ff @( posedge clk ) begin
        if (rst) begin
            arch_pc <= `INIT_PC;
        end
        else if(has_mispred || has_except || has_interrupt) begin

        end
        else begin
            for(j=0;j<`COMMIT_WIDTH;j=j+1) begin
                if (willCommit_vld[j]) begin
                    arch_pc <= alloc_pc[j+1];
                end
            end
        end
    end
    generate
        for(i=0;i<`COMMIT_WIDTH+1;i=i+1) begin:gen_for
            if(i==0) begin:gen_if
                assign alloc_pc[i] = arch_pc;
            end
            else begin:gen_else
                assign alloc_pc[i] = alloc_pc[i-1] + (willCommit_data[i-1].isRVC ? 2:4);
            end
        end
    endgenerate


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
        .clk              (clk              ),
        .rst              (rst              ),

        .o_can_enq        (o_can_enq        ),
        .i_enq_vld        (i_enq_vld        ),
        .i_enq_req        (i_enq_req        ),
        .i_enq_data       (i_enq_data       ),
        .o_ptr_flipped    (),
        .o_alloc_id       (o_alloc_id       ),


        .i_read_dqIdx     (i_read_dqIdx     ),
        .o_read_data      (o_read_data      ),
        .i_clear_vld      (i_clear_vld      ),
        .i_clear_dqIdx    (i_clear_dqIdx    ),

        .o_willClear_vld  ( willCommit_vld  ),
        .o_willClear_idx  ( willCommit_idx  ),
        .o_willClear_data ( willCommit_data )
    );

/****************************************************************************************************/
//
//
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
        wire[`WDEF(`COMMIT_WIDTH)] temp_0;
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            if (i==0) begin :gen_if
                assign temp_0[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
            end
            else begin:gen_else
                assign temp_0[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
            end
        end
    endgenerate
    assign has_mispred = (|temp_0) && bmhr.mispred;


/****************************************************************************************************/
//
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
        wire[`WDEF(`COMMIT_WIDTH)] temp_1;
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            if (i==0) begin :gen_if
                assign temp_1[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
            end
            else begin:gen_else
                assign temp_1[i] = willCommit_vld[i] && (willCommit_idx[i] == bmhr.rob_idx.idx);
            end
        end
    endgenerate
    assign has_except = (|temp_1) && ehr.has_except;







endmodule
