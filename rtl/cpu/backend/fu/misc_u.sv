
`include "fu_define.svh"


//TODO
module misc_u #(
    parameter int BYPASS_WID = 4
)(
    input wire clk,
    input wire rst,
    //ctrl info
    input wire i_has_vld,
    input fuInfo_t i_fuInfo,
    output wire o_fu_stall,
    //data input
    input wire[`XDEF] i_data[BYPASS_WID],
    input wire[`WDEF($clog2(BYPASS_WID)-1)] i_data_idx[`NUMSRCS_INT],//only need to save data_idx

    //imm
    input wire[`IMMDEF] i_imm,
    //pc (branch/auipc only)
    input wire[`XDEF] i_pc,
    //predTakenpc(branch only)
    input wire[`XDEF] i_predTakenpc,

    //wb, rd_idx will be used to fast bypass
    input wire i_wb_stall,
    output reg o_complete,
    output wbInfo_t o_wbInfo
);
    reg saved_has_vld;
    fuInfo_t saved_fuInfo;
    reg[`WDEF($clog2(BYPASS_WID)-1)] saved_data_idx[`NUMSRCS_INT];
    //single cycle execute
    wire complete = saved_has_vld;

    always_ff @( posedge clk ) begin : blockName
        if (rst==true) begin
            saved_has_vld <= false;
            saved_robIdx <= 0;
            save_rd_wen <= false;
        end
        else if (i_has_vld && (!i_wb_stall)) begin
            saved_has_vld <= true;
            saved_data_idx <= i_data_idx;
            saved_fuInfo <= i_fuInfo;
        end
        else if (complete) begin
            saved_has_vld <= i_has_vld;
        end
    end

    wire[`XDEF] src0 = i_data[saved_data_idx[0]];
    wire[`XDEF] src1 = i_data[saved_data_idx[1]];

    //auipc
    wire[`XDEF] auipc = i_pc + i_imm;

    //unconditional branch
    wire[`XDEF] jal = i_pc + i_imm;
    wire [`XDEF] jalr = src0 + i_imm;
    wire jal_taken =
    (saved_fuInfo.micOp == MicOp_t::jal) ? true :
    (saved_fuInfo.micOp == MicOp_t::jalr) ? true :
    false;
    wire[`XDEF] jal_takenpc =
    (saved_fuInfo.micOp == MicOp_t::jal) ? jal :
    (saved_fuInfo.micOp == MicOp_t::jalr) ? jalr :
    jalr;
    wire jalr_misPred= jal_takenpc != i_predTakenpc;

    //conditional branch
    wire[`XDEF] branch_takenpc = i_pc + i_imm;
    wire[`XDEF] branch_notakenpc = i_pc + 4;

    wire beq = src0 == src1;
    wire bne = src0 != src1;
    wire blt = $signed(src0) < $signed(src1);
    wire bge = $signed(src0) >= $signed(src1);
    wire bltu = src0 < src1;
    wire bgeu = src0 >= src1;

    wire branch_taken =
    (saved_fuInfo.micOp == MicOp_t::beq) ? beq :
    (saved_fuInfo.micOp == MicOp_t::bne) ? bne :
    (saved_fuInfo.micOp == MicOp_t::blt) ? blt :
    (saved_fuInfo.micOp == MicOp_t::bge) ? bge :
    (saved_fuInfo.micOp == MicOp_t::bltu) ? bltu :
    (saved_fuInfo.micOp == MicOp_t::bgeu) ? bgeu :
    false;

    wire misPred = branch_taken ? (i_predTakenpc != branch_takenpc) : (i_predTakenpc != branch_notakenpc);
    assign o_misPred_taken = real_taken & misPred;


    wire[`XDEF] calc_data =
    (saved_fuInfo.micOp == MicOp_t::jal) ? jal :
    (saved_fuInfo.micOp == MicOp_t::jalr) ? jalr :
    (saved_fuInfo.micOp == MicOp_t::auipc) ? auipc :
    0;



    always @(posedge clk) begin
        if (rst) begin
            o_complete <= false;
        end
        else if (!i_wb_stall) begin
            o_complete <= complete;
            //output
            o_wbInfo.robIdx <= saved_fuInfo.robIdx;
            o_wbInfo.use_imm <= saved_fuInfo.use_imm;
            o_wbInfo.immBIdx <= saved_fuInfo.immBIdx;
            // o_wbInfo.is_branch <= false;// alu do not need
            // o_wbInfo.branchBIdx <= 0;// alu do not need
            o_wbInfo.iprd_wen <= saved_fuInfo.iprd_wen;
            o_wbInfo.iprd_idx <= saved_fuInfo.iprd_idx;
            o_wbInfo.wb_data <= calc_data;
        end
    end

    assign o_fu_stall = i_wb_stall;

endmodule
