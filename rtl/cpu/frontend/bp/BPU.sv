`include "frontend_define.svh"


// BPU -> FTQ -> backend

module BPU (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    input wire i_update_vld,
    output wire o_update_finished,
    input BPupdateInfo_t i_BPupdateInfo,

    // predict output -> ftq
    input wire i_ftq_rdy,
    output wire o_pred_vld,
    output ftqInfo_t o_pred_ftqInfo
);
    wire squash_dueToBackend = i_squash_vld;
    wire squash_vld;


    reg[`XDEF] base_pc, s1_base_pc, s2_base_pc;

    wire lookup_req = 1;

    wire ftb_lookup_gnt;
    wire s1_ftb_lookup_hit, s1_ftb_lookup_hit_rdy;
    ftbInfo_t s2_ftb_lookup_info;
    FTB u_FTB(
        .clk              ( clk              ),
        .rst              ( rst              ),
        .i_squash_vld     ( squash_vld       ),

        .i_lookup_req     ( lookup_req     ),
        .o_lookup_gnt     ( ftb_lookup_gnt     ),
        .i_lookup_pc      ( base_pc      ),
        .o_lookup_ftbInfo ( s2_ftb_lookup_info  ),
        .o_lookup_hit     ( s1_ftb_lookup_hit     ),
        .o_lookup_hit_rdy ( s1_ftb_lookup_hit_rdy ),

        .i_update_req     ( i_update_vld     ),
        .o_update_finished  ( o_update_finished  ),
        .i_update_pc      ( i_BPupdateInfo.startAddr  ),
        .i_update_ftbInfo ( i_BPupdateInfo.ftb_update )
    );

/****************************************************************************************************/
// lookup predictors
/****************************************************************************************************/


    reg s2_ftb_lookup_hit;
    reg s2_ftb_lookup_hit_rdy;
    reg s2_ftbPred_use; // ftb lookup hit
    reg[`XDEF] s2_ftb_unhit_fallthruAddr;
    always_ff @( posedge clk ) begin
        if (rst) begin
            s2_ftbPred_use <= 0;
            s2_ftb_lookup_hit_rdy <= 0;
        end
        else begin
            if (squash_vld) begin
                s2_ftbPred_use <= 0;
                s2_ftb_lookup_hit_rdy <= 0;
            end
            else if (i_ftq_rdy) begin
                s2_ftbPred_use <= s1_ftb_lookup_hit_rdy && s1_ftb_lookup_hit;
                s2_ftb_lookup_hit <= s1_ftb_lookup_hit;
                s2_ftb_lookup_hit_rdy <= s1_ftb_lookup_hit_rdy;
            end

            s2_ftb_unhit_fallthruAddr <= s1_base_pc + (`FTB_PREDICT_WIDTH);
        end
    end


/****************************************************************************************************/
// get the lookup info and calcuate the next pc
/****************************************************************************************************/

    wire s2_taken = s2_ftb_lookup_info.counter >= 2;
    wire[`XDEF] s2_predNPC = ftbFuncs::calcNPC(s2_base_pc, s2_taken, s2_ftb_lookup_info);

    always_ff @( posedge clk ) begin
        if (rst) begin
            base_pc <= `INIT_PC;
        end
        else begin
            if (squash_dueToBackend) begin
                base_pc <= i_squashInfo.arch_pc;
            end
            else if (s2_ftbPred_use && i_ftq_rdy) begin
                base_pc <= s2_predNPC;
            end
            else if (!i_update_vld && i_ftq_rdy) begin
                // donot pred when updating
                base_pc <= base_pc + (`FTB_PREDICT_WIDTH);
            end

            if (i_ftq_rdy) begin
                s1_base_pc <= base_pc;
                s2_base_pc <= s1_base_pc;
            end

        end
    end

    // when lookup hit in ftb , we need to squash
    assign squash_vld = squash_dueToBackend || s2_ftbPred_use;
/****************************************************************************************************/
// send predict result to ftq
/****************************************************************************************************/


    assign o_pred_vld = s2_ftb_lookup_hit_rdy;

    assign o_pred_ftqInfo = '{
        startAddr : s2_base_pc,
        endAddr : s2_ftbPred_use ? ftbFuncs::calcFallthruAddr(s2_base_pc, s2_ftb_lookup_info) - 1 : s2_ftb_unhit_fallthruAddr - 1,
        taken : s2_taken,
        targetAddr : ftbFuncs::calcTargetAddr(s2_base_pc, s2_ftb_lookup_info),
        // ftb meta
        hit_on_ftb : s2_ftb_lookup_hit,
        branch_type : s2_ftb_lookup_info.branch_type,
        ftb_counter : s2_ftb_lookup_info.counter
        // or more
    };


endmodule

