`ifndef __CORE_COMM_SVH__
`define __CORE_COMM_SVH__

`include "base.svh"

`define FTB_PREDICT_WIDTH 24 // byte
`define CACHELINE_SIZE 32 // Byte
`define XLEN 64
`define XLEN_64
`define INIT_PC 64'h0000000080000000

// cache region fast define
`define BLKDEF `WDEF(`XLEN - $clog2(`CACHELINE_SIZE))
`define BLK_RANGE `XLEN - 1 : $clog2(`CACHELINE_SIZE)

`define BLOCKADDR(x) ((``x``)>>$clog2(`CACHELINE_SIZE))
`define PADDR(x) ``x``[`PALEN-1:0]

//int logic register index def
`define ILRIDX_DEF `WDEF($clog2(32))
//flt logic register index def
`define FLRIDX_DEF `ILRIDX_DEF
//xlen fast define
`define XDEF `WDEF(`XLEN)
//instruction fast define
`define IDEF `WDEF(32)

`define CSRIDX_DEF `WDEF(12)
`define PCDEF `WDEF(64)
`define IMMDEF `WDEF(20)

`define FTQ_SIZE 32
`define IPHYREG_NUM 80
`define IMMBUFFER_SIZE 60
`define ROB_SIZE 128
`define INTDQ_SIZE 16
`define MEMDQ_SIZE 16
`define LDIQ_SIZE 16
`define LQSIZE 64
`define SQSIZE 64

`define SSIT_SIZE 1024
`define MEMDEP_FOLDPC_WIDTH $clog2(`SSIT_SIZE)
`define LFST_SIZE 32

`include "core_priv.svh"

`define OLDER_THAN(a, b) ((``a``.flipped == ``b``.flipped) ? (``a``.idx < ``b``.idx) : (``a``.idx > ``b``.idx))

typedef logic [`WDEF(`PALEN)] paddr_t;

typedef logic [`WDEF($clog2(`FTQ_SIZE))] ftqIdx_t;
typedef logic [`WDEF($clog2(`FTB_PREDICT_WIDTH))] ftqOffset_t;
typedef struct packed {
    logic flipped;
    logic [`WDEF($clog2(`ROB_SIZE))] idx;
} robIdx_t;
// typedef logic [`WDEF($clog2(`ROB_SIZE))] robIdx_t;
typedef logic [`WDEF($clog2(`IMMBUFFER_SIZE))] irobIdx_t;  // the immBuffer idx

//[int/fp][logic/physic]r[dest/src]Idx
typedef logic [`WDEF($clog2(32))] ilrIdx_t;  //the int logic regfile idx
typedef logic [
`WDEF($clog2(`IPHYREG_NUM))
] iprIdx_t;  //the int physic regfile idx
typedef logic [`WDEF(12)] csrIdx_t;  //the csr regfile idx

typedef logic [`IMMDEF] imm_t;

typedef struct packed {
    logic flipped;
    logic [`WDEF($clog2(`LQSIZE))] idx;
} lqIdx_t;

typedef struct packed {
    logic flipped;
    logic [`WDEF($clog2(`SQSIZE))] idx;
} sqIdx_t;

package rv_trap_t;
    //mtvec mode:
    //0:Direct All exceptions set pc to BASE.
    //1:Vectored Asynchronous interrupts set pc to BASE+4×cause.
    `define TRAPCODE_WIDTH 16
    // mcause (actually, 16bits mcause reg is enough)
    typedef enum logic [
    `WDEF(`TRAPCODE_WIDTH)
    ] {
        //instruction fetch and decode
        pcMisaligned = 0,  // instruction address misaligned
        fetchFault = 1,  // instruction access fault
        instIllegal = 2,  // Illegal instruction
        breakpoint = 3,
        //load, store/AMO
        loadMisaligned = 4,
        loadFault = 5,
        storeMisaligned = 6,
        storeFault = 7,
        //env call
        ucall = 8,
        scall = 9,
        mcall = 11,
        fetchPageFault = 12,
        loadPageFault = 13,
        storePageFault = 15,
        //NOTE:24-31/48-63, designated for custom use
        reExec = 128,
        reserved_exception
    } exception;
    typedef enum logic [
    `WDEF(`TRAPCODE_WIDTH)
    ] {
        sSoft = 1,  // Supervisor software interrupt
        mSoft = 3,
        sTimer = 5,  // Supervisor timer interrupt
        mTimer = 7,
        sExter = 9,  // Supervisor external interrupt
        mExter = 11,
        //>=16 Designated for platform use
        reserved_interrupts
    } interrupt;

endpackage


`endif
