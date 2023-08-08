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



// FTB
typedef struct packed {
    logic carry;
    logic[`WDEF(`FTB_FALLTHRU_WIDTH)] fallthruAddr;
    tarStat_t::_ tarStat;
    logic[`WDEF(`FTB_TARGET_WIDTH)] targetAddr;
    BranchType::_ branch_type;
    logic[`WDEF(2)] counter;
} ftbInfo_t;

typedef struct packed{
    logic[`WDEF(`FTB_TAG_WIDTH)] tag;
    logic vld;
    ftbInfo_t info;
} ftbEntry_t;

//ftq
typedef struct {
    logic[`XDEF] startAddr;
    logic[`XDEF] endAddr;
    logic taken;
    logic[`XDEF] targetAddr;
    // meta data
    logic hit_on_ftb;
    BranchType::_ branch_type;
    logic[`WDEF(2)] ftb_counter;
} ftqInfo_t;

typedef struct packed {
    logic[`XDEF] startAddr;
    ftbInfo_t ftb_update;
} BPupdateInfo_t;

typedef struct packed {
    logic[`XDEF] startAddr;
    logic[`WDEF(`FTB_PREDICT_WIDTH)] fetchBlock_size;
} ftq2icacheInfo_t;


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
endpackage


`endif
