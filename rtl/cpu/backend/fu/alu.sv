
`include "fu_define.svh"
`include "decode_define.svh"

//TODO:
module alu #(
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
    input wire[`WDEF($clog2(BYPASS_WID))] i_data_idx[`NUMSRCS_INT],//only need to save data_idx

    //wb, rd_idx will be used to fast bypass
    input wire i_wb_stall,
    output reg o_complete,
    output wbInfo_t o_wbInfo
);
    reg saved_has_vld;
    fuInfo_t saved_fuInfo;
    reg[`WDEF($clog2(BYPASS_WID))] saved_data_idx[`NUMSRCS_INT];
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

    // assign o_complete = saved_has_vld;
    // assign o_robIdx = saved_fuInfo.robIdx;
    // assign o_wb_vld = saved_fuInfo.iprd_wen;
    // assign o_iprd_idx = saved_fuInfo.iprd_idx;



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
    (saved_fuInfo.micOp == MicOp_t::sltu) ? slru :
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
            // o_wbInfo.brob_idx <= 0;// alu do not need
            o_wbInfo.iprd_wen <= saved_fuInfo.iprd_wen;
            o_wbInfo.iprd_idx <= saved_fuInfo.iprd_idx;
            o_wbInfo.wb_data <= calc_data;
        end
    end

    assign o_fu_stall = i_wb_stall;



endmodule
