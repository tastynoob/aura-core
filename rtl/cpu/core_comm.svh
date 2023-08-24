`ifndef __CORE_COMM_SVH__
`define __CORE_COMM_SVH__

`include "base.svh"

`define FTB_PREDICT_WIDTH 16 // byte (up to 8 RVC inst)

`define CACHELINE_SIZE 32
`define XLEN 64
`define XLEN_64
`define INIT_PC 64'h8000000000000000

`define CSRIDX_DEF `WDEF(12)
`define PCDEF `WDEF(64)
`define IMMDEF `WDEF(20)

`define FTQ_SIZE 16
`define IPHYREG_NUM 80
`define IMMBUFFER_SIZE 40
`define ROB_SIZE 128

typedef logic[`WDEF($clog2(`FTQ_SIZE))] ftqIdx_t;
typedef logic[`WDEF($clog2(`FTB_PREDICT_WIDTH))] ftqOffset_t;
typedef struct packed {
    logic flipped;
    logic [`WDEF($clog2(`ROB_SIZE))] idx;
} robIdx_t;
// typedef logic [`WDEF($clog2(`ROB_SIZE))] robIdx_t;
typedef logic [`WDEF($clog2(`IMMBUFFER_SIZE))] irobIdx_t; // the immBuffer idx

//[int/fp][logic/physic]r[dest/src]Idx
typedef logic [`WDEF($clog2(32))] ilrIdx_t;//the int logic regfile idx
typedef logic [`WDEF($clog2(`IPHYREG_NUM))] iprIdx_t;//the int physic regfile idx
typedef logic [`WDEF(12)] csrIdx_t;//the csr regfile idx

typedef logic [`IMMDEF] imm_t;


package rv_trap_t;
//mtvec mode:
//0:Direct All exceptions set pc to BASE.
//1:Vectored Asynchronous interrupts set pc to BASE+4×cause.

    // mcause (actually, 16bits mcause reg is enough)
    typedef enum logic[`WDEF(16)]{
        //instruction fetch and decode
        pcUnaligned=0, // instruction address misaligned
        fetchFault=1, // instruction access fault
        instIllegal=2,// Illegal instruction
        breakpoint=3,
        //load, store/AMO
        loadMisaligned=4,
        loadFault=5,
        storeMisaligned=6,
        storeFault=7,
        //env call
        ucall=8,
        scall=9,
        mcall=11,
        fetchPageFault=12,
        loadPageFault=13,
        storePageFault=15,
        //NOTE:24-31/48-63, designated for custom use
        //math compute
        badDivisor=24, // div/fdiv, it would not to throw trap in standard riscv
        reserved_exception
    }exception;
    typedef enum logic[`WDEF(16)]{
        sSoft=1, // Supervisor software interrupt
        mSoft=3,
        sTimer=5, // Supervisor timer interrupt
        mTimer=7,
        sExter=9, // Supervisor external interrupt
        mExter=11,
        //>=16 Designated for platform use
        reserved_interrupts
    }interrupt;

endpackage


`include "core_comm.svh"


`endif
