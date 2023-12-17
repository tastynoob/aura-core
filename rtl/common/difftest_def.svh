`ifndef __DIFFTEST_DEF_SVH__
`define __DIFFTEST_DEF_SVH__


package difftest_def;

typedef enum int {
    AT_fetchQue,
    AT_decode,
    AT_rename,
    AT_dispQue,
    AT_issueQue,
    AT_fu,
    AT_lq,
    AT_sq,
    NUMPOS
}InstPos;


typedef enum int {
    META_ISBRANCH,
    META_ISLOAD,
    META_ISSTORE,
    META_NPC,
    META_VADDR,
    META_PADDR
}MetaKeys;

endpackage



`endif
