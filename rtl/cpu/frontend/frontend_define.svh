`ifndef __FORNTEND_DEFINE_SVH__
`define __FORNTEND_DEFINE_SVH__


`include "frontend_config.svh"


package tarStat_t;
    typedef enum logic[2:0] {
        FIT,// {higher_bits, targte}
        OVF,// {higher_bits + 1, targte}
        UDF// {higher_bits - 1, targte}
     } _;
endpackage

// uBTB
typedef struct {
    logic hit;
    logic taken;
    logic[`WDEF(2)] scnt;
    logic[`XDEF] fallthruAddr;
    logic[`XDEF] targetAddr;
    logic[`XDEF] nextAddr;
} uBTBInfo_t;

// FTB
typedef struct packed {
    logic carry;
    logic[`WDEF(`FTB_FALLTHRU_WIDTH)] fallthruAddr;
    tarStat_t::_ tarStat;
    logic[`WDEF(`FTB_TARGET_WIDTH)] targetAddr;
    BranchType::_ branch_type;
} ftbInfo_t;

//ftq
typedef struct {
    logic[`XDEF] startAddr;
    logic[`XDEF] endAddr;
    logic[`XDEF] nextAddr;
    logic taken;
    logic[`XDEF] targetAddr;
    // ubtb meta
    logic hit_on_ubtb;
    logic ubtb_scnt;
    // ftb meta
    logic hit_on_ftb;
    BranchType::_ branch_type;
} BPInfo_t;

typedef struct {
    logic[`XDEF] startAddr;
    logic[`XDEF] fallthruAddr;
    logic[`XDEF] targetAddr;
    BranchType::_ branch_type;
    logic taken;
    logic mispred;
    // original ubtb meta
    logic hit_on_ubtb;
    logic[`WDEF(2)] ubtb_scnt;
    // original ftb meta
    logic hit_on_ftb;
} BPupdateInfo_t;

typedef struct {
    logic[`XDEF] startAddr;
    logic[`SDEF(`FTB_PREDICT_WIDTH)] fetchBlock_size;
    logic taken;
    logic[`XDEF] nextAddr;
} ftq2icacheInfo_t;


typedef struct {
    logic[`XDEF] fallthru;
    logic isCond;
    logic isDirect;
    logic isIndirect;
    logic isBr;
    logic[`XDEF] target;
    logic[`XDEF] simplePredNPC;
} preDecInfo_t;

package ftbFuncs;
    function automatic logic[`XDEF] calcFallthruAddr(logic[`XDEF] base_pc, ftbInfo_t ftbInfo);
        calcFallthruAddr = {base_pc[`XLEN-1 : `FTB_FALLTHRU_WIDTH+1] + ftbInfo.carry, ftbInfo.fallthruAddr, 1'b0};
    endfunction

    function automatic logic[`XDEF] calcTargetAddr(logic[`XDEF] base_pc, ftbInfo_t ftbInfo);
        logic[`WDEF(`XLEN - `FTB_TARGET_WIDTH - 1)] higher;
        higher = ftbInfo.tarStat == tarStat_t::FIT ? base_pc[`XLEN-1 : `FTB_TARGET_WIDTH+1] :
                ftbInfo.tarStat == tarStat_t::OVF ? base_pc[`XLEN-1 : `FTB_TARGET_WIDTH+1] + 1 :
                ftbInfo.tarStat == tarStat_t::UDF ? base_pc[`XLEN-1 : `FTB_TARGET_WIDTH+1] - 1 :
                base_pc[`XLEN-1 : `FTB_TARGET_WIDTH+1];
        calcTargetAddr = {higher, ftbInfo.targetAddr, 1'b0};
    endfunction

    function automatic logic[`XDEF] calcNPC(logic[`XDEF] base_pc, logic taken ,ftbInfo_t ftbInfo);
        logic[`XDEF] fallthruAddr = calcFallthruAddr(base_pc, ftbInfo);
        logic[`XDEF] targetAddr = calcTargetAddr(base_pc, ftbInfo);
        calcNPC = taken ? targetAddr : fallthruAddr;
    endfunction

    function automatic logic[`WDEF(2)] counterUpdate(logic[`WDEF(2)] source, logic taken);
        logic[`WDEF(2)] counter_0 = ((source==0) ? 0 : source - 1);
        logic[`WDEF(2)] counter_1 = ((source==3) ? 3 : source + 1);
        counterUpdate = taken ? counter_1 : counter_0;
    endfunction

    function automatic tarStat_t::_ calcuTarStat(logic[`XDEF] start, logic[`XDEF] target);
        calcuTarStat =
        target[`FTB_TARGET_WIDTH+3:`FTB_TARGET_WIDTH+1] == start[`FTB_TARGET_WIDTH+3:`FTB_TARGET_WIDTH+1] ? tarStat_t::FIT :
        target[`FTB_TARGET_WIDTH+3:`FTB_TARGET_WIDTH+1] > start[`FTB_TARGET_WIDTH+3:`FTB_TARGET_WIDTH+1] ? tarStat_t::OVF :
        tarStat_t::UDF;
    endfunction
endpackage


`endif
