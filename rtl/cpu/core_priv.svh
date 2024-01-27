`ifndef __CORE_PRIV_SVH__
`define __CORE_PRIV_SVH__

`include "core_config.svh"

`define SV39_SUPPORT 1

`define PALEN 36

`define VADDR(x) ``x``[39-1:0]


`define CSR_MHARTID 'hf14
`define CSR_MSTATUS 'h300
`define CSR_MIE 'h304
`define CSR_MTVEC 'h305
`define CSR_MEPC 'h341
`define CSR_MCAUSE 'h342
`define CSR_MTVAL 'h343
`define CSR_MIP 'h344

`define MODE_M 3
`define MODE_S 1
`define MODE_U 0

`define GETMODE(x) ``x``[9:8]
`define CSR_READONLY(x) (``x``[11:10] == 2'b11)


typedef struct {
    // trap info
    logic interrupt_vectored;
    logic[`WDEF(2)] level;
    logic[`XDEF] status;
    logic[`XDEF] tvec;
} csr_in_pack_t;

typedef struct {
    // trap handle
    logic has_trap;
    logic[`XDEF] epc;
    logic[`XDEF] cause;
    logic[`XDEF] tval;
} trap_pack_t;


`define INIT_MSTATUS (64'h0000000a_00000000)
`define MSTATUS_READ_MASK (64'h8000003F_007FFFEA)
`define MSTATUS_WRITE_MASK (64'h80000030_007FFFEA)
typedef struct packed {
    logic sd;
    logic[`WDEF(25)] wpri4;
    logic mbe;
    logic sbe;
    logic[`WDEF(2)] sxl;
    logic[`WDEF(2)] uxl;
    logic[`WDEF(9)] wpri3;
    logic tsr;
    logic tw;
    logic tvm;
    logic mxr;
    logic sum;
    logic mprv;
    logic[`WDEF(2)] xs;
    logic[`WDEF(2)] fs;
    logic[`WDEF(2)] mpp;
    logic[`WDEF(2)] vs;
    logic spp;
    logic mpie;
    logic ube;
    logic spie;
    logic wpri2;
    logic mie;
    logic wpri1;
    logic sie;
    logic wpri0;
} mstatus_csr_t;

typedef struct packed {
    logic[`WDEF(`XLEN-2)] base;
    logic[`WDEF(2)] mode;
} mtvec_csr_t;

`define MIP_MIE_WRITE_MASK (64'h555)
typedef struct packed {
    logic meip;
    logic zero5;
    logic seip;
    logic zero4;
    logic mtip;
    logic zero3;
    logic stip;
    logic zero2;
    logic msip;
    logic zero1;
    logic ssip;
    logic zero0;
} mip_csr_t;

typedef struct packed {
    logic meie;
    logic zero5;
    logic seie;
    logic zero4;
    logic mtie;
    logic zero3;
    logic stie;
    logic zero2;
    logic msie;
    logic zero1;
    logic ssie;
    logic zero0;
} mie_csr_t;

typedef struct packed {
    logic interrupt;
    logic[`WDEF(63)] except_code;
} mcause_csr_t;


`endif
