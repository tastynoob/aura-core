
`include "core_define.svh"

module alu (
    input wire clk,
    input wire rst,

    output wire o_fu_stall,
    //ctrl info
    input wire i_vld,
    input fuInfo_t i_fuInfo,

    // export bypass
    output wire o_willwrite_vld,
    output iprIdx_t o_willwrite_rdIdx,
    output wire[`XDEF] o_willwrite_data,

    //wb, rd_idx will be used to fast bypass
    input wire i_wb_stall,
    output wire o_wb_vld,
    output valwbInfo_t o_wbInfo
);

    reg saved_vld;
    fuInfo_t saved_fuInfo;

    always_ff @( posedge clk ) begin : blockName
        if (rst==true) begin
            saved_vld <= 0;
            saved_fuInfo.rd_wen <= 0;
        end
        else if (!i_wb_stall) begin
            saved_vld <= i_vld;
            saved_fuInfo <= i_fuInfo;
        end
    end


    wire[`XDEF] src0 = saved_fuInfo.srcs[0];
    wire[`XDEF] src1 = saved_fuInfo.srcs[1];

    wire[5:0] shifter = src1[5:0];

    wire[`XDEF] lui = {{32{1'b1}},src1[19:0],12'd0};
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
    wire[`XDEF] slt = {63'd0,sub[63]};
    // unsigned
    // src0 > src1 : fasle : src0 - src1 > 0
    wire[`XDEF] sltu = src0 < src1;


    wire[`XDEF] calc_data =
    (saved_fuInfo.micOp == MicOp_t::lui) ? lui :
    (saved_fuInfo.micOp == MicOp_t::add) ? add :
    (saved_fuInfo.micOp == MicOp_t::sub) ? sub :
    (saved_fuInfo.micOp == MicOp_t::addw) ? addw :
    (saved_fuInfo.micOp == MicOp_t::subw) ? subw :
    (saved_fuInfo.micOp == MicOp_t::sll) ? sll :
    (saved_fuInfo.micOp == MicOp_t::srl) ? srl :
    (saved_fuInfo.micOp == MicOp_t::sra) ? sra :
    (saved_fuInfo.micOp == MicOp_t::sllw) ? sllw :
    (saved_fuInfo.micOp == MicOp_t::srlw) ? srlw :
    (saved_fuInfo.micOp == MicOp_t::sraw) ? sraw :
    (saved_fuInfo.micOp == MicOp_t::_xor) ? _xor :
    (saved_fuInfo.micOp == MicOp_t::_or) ? _or :
    (saved_fuInfo.micOp == MicOp_t::_and) ? _and :
    (saved_fuInfo.micOp == MicOp_t::slt) ? slt :
    (saved_fuInfo.micOp == MicOp_t::sltu) ? sltu :
    0;

    reg wb_vld;
    valwbInfo_t wbInfo;
    always_ff @(posedge clk) begin
        if (rst) begin
            wb_vld <= 0;
            wbInfo.rd_wen <= false;
        end
        else if (!i_wb_stall) begin
            wbInfo.rob_idx <= saved_fuInfo.rob_idx;
            wbInfo.irob_idx <= saved_fuInfo.irob_idx;
            wbInfo.rd_wen <= saved_fuInfo.rd_wen;
            wbInfo.iprd_idx <= saved_fuInfo.iprd_idx;
            wbInfo.result <= calc_data;
        end
    end

    assign o_willwrite_vld = saved_fuInfo.rd_wen;
    assign o_willwrite_rdIdx = saved_fuInfo.iprd_idx;
    assign o_willwrite_data = calc_data;

    assign o_fu_stall = i_wb_stall;
    assign o_wb_vld = wb_vld;
    assign o_wbInfo = wbInfo;



endmodule
