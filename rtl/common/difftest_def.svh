`ifndef __DIFFTEST_DEF_SVH__
`define __DIFFTEST_DEF_SVH__


package difftest_def;

typedef enum int {
    AT_fetch,
    AT_decode,
    AT_rename,
    AT_dispQue,
    AT_issueQue,
    AT_fu,
    AT_wb,
    AT_lq,
    AT_sq,
    NUMPOS
}InstPos;


typedef enum int {
    META_ISBRANCH,
    META_ISLOAD,
    META_ISSTORE,
    META_ISMV,
    META_MISPRED,// branch only
    META_NPC,// branch only
    META_VADDR,// load/store only
    META_PADDR,// load/store only
    NUM_META
}MetaKeys;

endpackage



`endif
