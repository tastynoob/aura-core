`include "backend_define.svh"


import "DPI-C" function void arch_sync_csrs(
    uint64_t mstatus,
    uint64_t mepc,
    uint64_t mcause
);


module priv_ctrl (
    input wire clk,
    input wire rst,

    output csr_in_pack_t o_priv_sysInfo,
    input trap_pack_t i_trap_handle,
    syscall_if.s if_syscall,

    input wire i_access,
    input csrIdx_t i_read_csrIdx,
    output wire o_read_illegal,
    output wire[`XDEF] o_read_val,

    input wire i_write,
    input csrIdx_t i_write_csrIdx,
    input wire[`XDEF] i_write_val
);
    reg[`WDEF(2)] cur_mode;

    wire[`XDEF] csr_mapping[4096];

    wire[`XDEF] mhartid = 0;
    mstatus_csr_t mstatus;
    mtvec_csr_t mtvec;
    mip_csr_t mip;
    mie_csr_t mie;
    reg[`XDEF] mepc;
    mcause_csr_t mcause;
    reg[`XDEF] mtval;

    assign csr_mapping[`CSR_MHARTID] = mhartid;
    assign csr_mapping[`CSR_MSTATUS] = mstatus;
    assign csr_mapping[`CSR_MTVEC] = mtvec;
    assign csr_mapping[`CSR_MEPC] = mepc;
    assign csr_mapping[`CSR_MCAUSE] = mcause;
    assign csr_mapping[`CSR_MTVAL] = mtval;

    reg csr_sync;
    always_ff @( negedge clk ) begin
        if (csr_sync) begin
            arch_sync_csrs(mstatus, mepc, mcause);
        end
    end
    always_ff @( posedge clk ) begin
        if (rst) begin
            csr_sync <= 1;
            cur_mode <= `MODE_M;
            mstatus <= `INIT_MSTATUS;
            mtvec <= 0;
            mip <= 0;
            mie <= 0;
            mepc <= 0;
            mcause <= 0;
            mtval <= 0;
        end
        else begin
            if (csr_sync) begin
                csr_sync <= 0;
            end
            // write csr
            if (i_write) begin
                csr_sync <= 1;
                assert(`GETMODE(i_write_csrIdx) <= cur_mode);
                case (i_write_csrIdx)
                    `include "csr_write.svh.tmp"
                    default: begin
                    end
                endcase
            end
            else if (i_trap_handle.has_trap) begin
                csr_sync <= 1;
                // except
                mepc <= i_trap_handle.epc;
                mcause <= i_trap_handle.cause;
                mtval <= i_trap_handle.tval;
                // update mstatus
                cur_mode <= `MODE_M;
                mstatus.mpp <= cur_mode;
                mstatus.mie <= 0;
                mstatus.mpie <= mstatus.mie;
            end
            else if (if_syscall.mret) begin
                csr_sync <= 1;
                // mret
                cur_mode <= mstatus.mpp;
                mstatus.mie <= mstatus.mpie;
                mstatus.mpie <= 1;
                mstatus.mpp <= `MODE_U;
            end
            // TODO:
            // ecall
            // mret/sret

        end
    end

    // check csr access permissions
    assign o_read_illegal = i_access && (`GETMODE(i_read_csrIdx) > cur_mode);

    assign o_read_val = (i_access && (`GETMODE(i_read_csrIdx) <= cur_mode)) ?
        csr_mapping[i_read_csrIdx] : 0;


    assign o_priv_sysInfo = '{
        mode : cur_mode,
        status : mstatus,
        epc : mepc,
        interrupt_vectored : (mtvec.mode == 1),
        tvec : {mtvec.base, 2'b00}
    };

endmodule
