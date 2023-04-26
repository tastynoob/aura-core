
`include "fu_define.svh"


//TODO
module misc_u #(
    parameter int BYPASS_WID = 4
)(
    input wire clk,
    input wire rst,
    //ctrl info
    input wire i_has_vld,
    input robIdx_t i_robIdx,
    input MicOp_t::_u i_micOp,
    input wire i_rd_wen,
    input iprIdx_t i_iprd_idx,
    //data input
    input wire[`XDEF] i_data[BYPASS_WID],
    input wire[`WDEF($clog2(BYPASS_WID)-1)] i_data_idx[`NUMSRCS_INT],//only need to save data_idx

    //imm
    input wire[`IMMDEF] i_imm,
    //pc
    input wire[`XDEF] i_pc,
    //predTakenpc
    input wire[`XDEF] i_predTakenpc,

    //wb, rd_idx will be used to fast bypass
    output wire o_complete,
    output robIdx_t o_robIdx,
    output wire o_wb_vld,
    output iprIdx_t o_iprd_idx,
    output wire[`XDEF] o_wb_data
);
    reg saved_has_vld;
    robIdx_t saved_robIdx;
    MicOp_t::_u saved_micOp;
    reg[`WDEF($clog2(BYPASS_WID)-1)] saved_data_idx[`NUMSRCS_INT];
    reg saved_rd_wen;
    iprIdx_t saved_rdIdx;

    always_ff @( posedge clk ) begin : blockName
        if (rst==true) begin
            saved_has_vld <= false;
            saved_robIdx <= 0;
            save_rd_wen <= false;
        end
        else if (i_has_vld) begin
            saved_has_vld <= true;
            saved_robIdx <= i_robIdx;
            saved_micOp <= i_micOp;
            saved_data_idx <= i_data_idx;
            saved_rd_wen <= false;
            saved_rdIdx <= i_iprd_idx;
        end
        else if (o_complete) begin
            saved_has_vld <= i_has_vld;
        end
    end
    //single cycle execute
    assign o_complete = saved_has_vld;
    assign o_robIdx = saved_robIdx;
    assign o_wb_vld = saved_rd_wen;
    assign o_iprd_idx = saved_rdIdx;

    wire[`XDEF] src0 = i_data[saved_data_idx[0]];
    wire[`XDEF] src1 = i_data[saved_data_idx[1]];

    //auipc
    wire[`XDEF] auipc = i_pc + i_imm;

    //direct branch
    wire[`XDEF] jal = i_pc + i_imm;
    wire [`XDEF] jalr = src0 + i_imm;
    wire jal_taken =
    (saved_micOp == MicOp_t::jal) ? true :
    (saved_micOp == MicOp_t::jalr) ? true :
    false;
    wire[`XDEF] jal_takenpc =
    (saved_micOp == MicOp_t::jal) ? jal :
    (saved_micOp == MicOp_t::jalr) ? jalr :
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
    (saved_micOp == MicOp_t::beq) ? beq :
    (saved_micOp == MicOp_t::bne) ? bne :
    (saved_micOp == MicOp_t::blt) ? blt :
    (saved_micOp == MicOp_t::bge) ? bge :
    (saved_micOp == MicOp_t::bltu) ? bltu :
    (saved_micOp == MicOp_t::bgeu) ? bgeu :
    false;

    wire misPred = branch_taken ? (i_predTakenpc != branch_takenpc) : (i_predTakenpc != branch_notakenpc);
    assign o_misPred_taken = real_taken & misPred;

endmodule
