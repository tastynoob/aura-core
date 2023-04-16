`ifndef __CORE_DEFINE_SVH__
`define __CORE_DEFINE_SVH__

`include "core_config.svh"

typedef logic [`WDEF($clog2(32))] ilrIdx_t;//the int logic regfile idx
typedef logic [`WDEF($clog2(`IPHYREG_NUM))] iprIdx_t;//the int physic regfile idx
typedef logic [`WDEF(12)] csrIdx_t;//the csr regfile idx

package rv_trap_t;
    typedef enum logic[`XDEF]{
        none
    }exception;
    typedef enum logic[`XDEF]{
        b
    }interrupt;
endpackage


`endif
