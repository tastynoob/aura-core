    wire[5:0] shifter = src1[5:0];
    wire[`XDEF] lui = {{32{src1[19]}},src1[19:0],12'd0};
    wire[`XDEF] add = src0 + src1;
    wire[`XDEF] sub = src0 - src1;
    wire[`XDEF] addw = {{32{add[31]}},add[31:0]};
    wire[`XDEF] subw = {{32{sub[31]}},sub[31:0]};
    wire[`XDEF] sll = (src0 << shifter);
    wire[`XDEF] srl = (src0 >> shifter);
    wire[`XDEF] sra = (({64{src0[63]}} << (7'd64 - {1'b0, shifter})) | (src0 >> shifter));

    wire[`WDEF(32)] sllw_ = (src0[31:0] << shifter[4:0]);
    wire[`WDEF(32)] srlw_ = (src0[31:0] >> shifter[4:0]);

    wire[`XDEF] sllw = {{32{sllw_[31]}},sllw_[31:0]};
    wire[`XDEF] srlw = {{32{srlw_[31]}},srlw_[31:0]};
    wire[`XDEF] sraw = (({64{src0[31]}} << (6'd31 - {1'b0, shifter[4:0]})) | (src0[31:0] >> shifter[4:0]));

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