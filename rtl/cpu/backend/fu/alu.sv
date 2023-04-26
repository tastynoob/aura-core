
`include "fu_define.svh"
`include "decode_define.svh"


module alu #(
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

    wire[5:0] shifter = src1[5:0];

    wire[`XDEF] lui = {{32{1'b1}},src1[19:0],{12{0}}};
    wire[`XDEF] add = src0 + src1;
    wire[`XDEF] sub = src0 - src1;
    wire[`XDEF] addw = {{32{add[31]}},add[31:0]};
    wire[`XDEF] subw = {{32{sub[31]}},sub[31:0]};
    wire[`XDEF] sll = (src0 << shifter);
    wire[`XDEF] srl = (src0 >> shifter);
    wire[`XDEF] sra = (({64{src0[63]}} << (7'd64 - {1'b0, shifter})) | (src0 >> shifter));
    wire[`XDEF] sllw = {{32{sll[31]}},sll[31:0]};
    wire[`XDEF] srlw = {{32{srl[31]}},srl[31:0]};
    wire[`XDEF] sraw = {{32{sra[31]}},sra[31:0]};

    wire[`XDEF] _xor = src0 ^ src1;
    wire[`XDEF] _or = src0 | src1;
    wire[`XDEF] _and = src0 & src1;
    // signed
    // src0 < src1 (src0 - src1 < 0)
    wire[`XDEF] slt = {{63{0}},sub[63]};
    // unsigned
    // src0 > src1 : fasle : src0 - src1 > 0
    wire[`XDEF] sltu = src0 < src1;


    assign o_wb_data =
    (saved_micOp == MicOp_t::lui) ? lui :
    (saved_micOp == MicOp_t::add) ? add :
    (saved_micOp == MicOp_t::sub) ? sub :
    (saved_micOp == MicOp_t::addw) ? addw :
    (saved_micOp == MicOp_t::subw) ? subw :
    (saved_micOp == MicOp_t::sll) ? sll :
    (saved_micOp == MicOp_t::srl) ? srl :
    (saved_micOp == MicOp_t::sra) ? sra :
    (saved_micOp == MicOp_t::sllw) ? sllw :
    (saved_micOp == MicOp_t::srlw) ? srlw :
    (saved_micOp == MicOp_t::sraw) ? sraw :
    (saved_micOp == MicOp_t::_xor) ? _xor :
    (saved_micOp == MicOp_t::_or) ? _or :
    (saved_micOp == MicOp_t::_and) ? _and :
    (saved_micOp == MicOp_t::slt) ? slt :
    (saved_micOp == MicOp_t::sltu) ? slru :
    0;

endmodule
