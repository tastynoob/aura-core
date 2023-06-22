`ifndef __CORE_DEFINE_SVH__
`define __CORE_DEFINE_SVH__

`include "core_config.svh"

typedef logic[`WDEF($clog2(`FSQ_SIZE)-1)] fsqIdx_t;


//[int/fp][logic/physic]r[dest/src]Idx
typedef logic [`WDEF($clog2(32))] ilrIdx_t;//the int logic regfile idx
typedef logic [`WDEF($clog2(`IPHYREG_NUM))] iprIdx_t;//the int physic regfile idx

typedef logic [`WDEF(12)] csrIdx_t;//the csr regfile idx
typedef logic [`WDEF($clog2(`ROB_SIZE))] robIdx_t;
typedef logic [`WDEF($clog2(`IMMBUFFER_SIZE)-1)] immBIdx_t; // the immBuffer idx
typedef logic [`WDEF($clog2(`BRANCHBUFFER_SIZE)-1)] branchBIdx_t; // the branchBuffer idx

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

typedef struct packed {
    // the trap type
    logic[`WDEF(16)] cause;
    // the cpu pc when trap triggered
    logic[`XDEF] epc;
    // the reason of trap
    // exception: maybe is 32'inst or mem access address
    // interrupt: nothing
    logic[`XDEF] tval;
} trapInfo_t;



`include "core_comm.svh"


`endif
