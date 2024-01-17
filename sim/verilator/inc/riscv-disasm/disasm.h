// See LICENSE for license details.

#ifndef _RISCV_DISASM_H
#define _RISCV_DISASM_H

#include "riscv-disasm/encoding.h"
#include <cstdint>
#include <cinttypes>
#include <string>
#include <sstream>
#include <vector>

#define NOINLINE __attribute__ ((noinline))
#define UNUSED __attribute__ ((unused))

#define insn_length(x) \
  (((x) & 0x03) < 0x03 ? 2 : \
   ((x) & 0x1f) < 0x1f ? 4 : \
   ((x) & 0x3f) < 0x3f ? 6 : \
   8)

#define X_SP 2

#define X_RA 1
#define X_SP 2
#define X_S0 8
#define X_A0 10
#define X_A1 11
#define X_Sn 16
#define Sn(n) ((n) < 2 ? X_S0 + (n) : X_Sn + (n))
#define RVC_R1S (Sn(insn.rvc_r1sc()))
#define RVC_R2S (Sn(insn.rvc_r2sc()))

const int NXPR = 32;
const int NFPR = 32;
const int NVPR = 32;
const int NCSR = 4096;

typedef uint64_t insn_bits_t;
class insn_t
{
public:
    insn_t() = default;
    insn_t(insn_bits_t bits) : b(bits) {}
    insn_bits_t bits() { return b; }
    int length() { return insn_length(b); }
    int64_t i_imm() { return xs(20, 12); }
    int64_t shamt() { return x(20, 6); }
    int64_t s_imm() { return x(7, 5) + (xs(25, 7) << 5); }
    int64_t sb_imm() { return (x(8, 4) << 1) + (x(25, 6) << 5) + (x(7, 1) << 11) + (imm_sign() << 12); }
    int64_t u_imm() { return xs(12, 20) << 12; }
    int64_t uj_imm() { return (x(21, 10) << 1) + (x(20, 1) << 11) + (x(12, 8) << 12) + (imm_sign() << 20); }
    uint64_t rd() { return x(7, 5); }
    uint64_t rs1() { return x(15, 5); }
    uint64_t rs2() { return x(20, 5); }
    uint64_t rs3() { return x(27, 5); }
    uint64_t rm() { return x(12, 3); }
    uint64_t csr() { return x(20, 12); }
    uint64_t iorw() { return x(20, 8); }
    uint64_t bs() { return x(30, 2); } // Crypto ISE - SM4/AES32 byte select.
    uint64_t rcon() { return x(20, 4); } // Crypto ISE - AES64 round const.

    int64_t rvc_imm() { return x(2, 5) + (xs(12, 1) << 5); }
    int64_t rvc_zimm() { return x(2, 5) + (x(12, 1) << 5); }
    int64_t rvc_addi4spn_imm() { return (x(6, 1) << 2) + (x(5, 1) << 3) + (x(11, 2) << 4) + (x(7, 4) << 6); }
    int64_t rvc_addi16sp_imm() { return (x(6, 1) << 4) + (x(2, 1) << 5) + (x(5, 1) << 6) + (x(3, 2) << 7) + (xs(12, 1) << 9); }
    int64_t rvc_lwsp_imm() { return (x(4, 3) << 2) + (x(12, 1) << 5) + (x(2, 2) << 6); }
    int64_t rvc_ldsp_imm() { return (x(5, 2) << 3) + (x(12, 1) << 5) + (x(2, 3) << 6); }
    int64_t rvc_swsp_imm() { return (x(9, 4) << 2) + (x(7, 2) << 6); }
    int64_t rvc_sdsp_imm() { return (x(10, 3) << 3) + (x(7, 3) << 6); }
    int64_t rvc_lw_imm() { return (x(6, 1) << 2) + (x(10, 3) << 3) + (x(5, 1) << 6); }
    int64_t rvc_ld_imm() { return (x(10, 3) << 3) + (x(5, 2) << 6); }
    int64_t rvc_j_imm() { return (x(3, 3) << 1) + (x(11, 1) << 4) + (x(2, 1) << 5) + (x(7, 1) << 6) + (x(6, 1) << 7) + (x(9, 2) << 8) + (x(8, 1) << 10) + (xs(12, 1) << 11); }
    int64_t rvc_b_imm() { return (x(3, 2) << 1) + (x(10, 2) << 3) + (x(2, 1) << 5) + (x(5, 2) << 6) + (xs(12, 1) << 8); }
    int64_t rvc_simm3() { return x(10, 3); }
    uint64_t rvc_rd() { return rd(); }
    uint64_t rvc_rs1() { return rd(); }
    uint64_t rvc_rs2() { return x(2, 5); }
    uint64_t rvc_rs1s() { return 8 + x(7, 3); }
    uint64_t rvc_rs2s() { return 8 + x(2, 3); }

    uint64_t rvc_lbimm() { return (x(5, 1) << 1) + x(6, 1); }
    uint64_t rvc_lhimm() { return (x(5, 1) << 1); }

    uint64_t rvc_r1sc() { return x(7, 3); }
    uint64_t rvc_r2sc() { return x(2, 3); }
    uint64_t rvc_rlist() { return x(4, 4); }
    uint64_t rvc_spimm() { return x(2, 2) << 4; }

    uint64_t rvc_index() { return x(2, 8); }

    uint64_t v_vm() { return x(25, 1); }
    uint64_t v_wd() { return x(26, 1); }
    uint64_t v_nf() { return x(29, 3); }
    uint64_t v_simm5() { return xs(15, 5); }
    uint64_t v_zimm5() { return x(15, 5); }
    uint64_t v_zimm10() { return x(20, 10); }
    uint64_t v_zimm11() { return x(20, 11); }
    uint64_t v_lmul() { return x(20, 2); }
    uint64_t v_frac_lmul() { return x(22, 1); }
    uint64_t v_sew() { return 1 << (x(23, 3) + 3); }
    uint64_t v_width() { return x(12, 3); }
    uint64_t v_mop() { return x(26, 2); }
    uint64_t v_lumop() { return x(20, 5); }
    uint64_t v_sumop() { return x(20, 5); }
    uint64_t v_vta() { return x(26, 1); }
    uint64_t v_vma() { return x(27, 1); }
    uint64_t v_mew() { return x(28, 1); }
    uint64_t v_zimm6() { return x(15, 5) + (x(26, 1) << 5); }

    uint64_t p_imm2() { return x(20, 2); }
    uint64_t p_imm3() { return x(20, 3); }
    uint64_t p_imm4() { return x(20, 4); }
    uint64_t p_imm5() { return x(20, 5); }
    uint64_t p_imm6() { return x(20, 6); }

    uint64_t zcmp_regmask() {
        unsigned mask = 0;
        uint64_t rlist = rvc_rlist();

        if (rlist >= 4)
            mask |= 1U << X_RA;

        for (uint64_t i = 5; i <= rlist; i++)
            mask |= 1U << Sn(i - 5);

        if (rlist == 15)
            mask |= 1U << Sn(11);

        return mask;
    }

    uint64_t zcmp_stack_adjustment(int xlen) {
        uint64_t stack_adj_base = 0;
        switch (rvc_rlist()) {
        case 15:
            stack_adj_base += 16;
        case 14:
            if (xlen == 64)
                stack_adj_base += 16;
        case 13:
        case 12:
            stack_adj_base += 16;
        case 11:
        case 10:
            if (xlen == 64)
                stack_adj_base += 16;
        case 9:
        case 8:
            stack_adj_base += 16;
        case 7:
        case 6:
            if (xlen == 64)
                stack_adj_base += 16;
        case 5:
        case 4:
            stack_adj_base += 16;
            break;
        }

        return stack_adj_base + rvc_spimm();
    }

private:
    insn_bits_t b;
    uint64_t x(int lo, int len) { return (b >> lo) & ((insn_bits_t(1) << len) - 1); }
    uint64_t xs(int lo, int len) { return int64_t(b) << (64 - lo - len) >> (64 - len); }
    uint64_t imm_sign() { return xs(31, 1); }
};

#include <string>
#include <sstream>
#include <algorithm>
#include <vector>

extern const char* xpr_name[NXPR];
extern const char* fpr_name[NFPR];
extern const char* vr_name[NVPR];
extern const char* csr_name(int which);

class arg_t
{
public:
    virtual std::string to_string(insn_t val) const = 0;
    virtual ~arg_t() {}
};

class disasm_insn_t
{
public:
    NOINLINE disasm_insn_t(const char* name_, uint32_t match, uint32_t mask,
        const std::vector<const arg_t*>& args)
        : match(match), mask(mask), args(args)
    {
        name = name_;
        std::replace(name.begin(), name.end(), '_', '.');
    }

    bool operator == (insn_t insn) const
    {
        return (insn.bits() & mask) == match;
    }

    const char* get_name() const
    {
        return name.c_str();
    }

    std::string to_string(insn_t insn) const
    {
        std::string s(name);

        if (args.size())
        {
            bool next_arg_optional = false;
            s += std::string(" ");
            for (size_t i = 0; i < args.size(); i++) {
                if (args[i] == nullptr) {
                    next_arg_optional = true;
                    continue;
                }
                std::string argString = args[i]->to_string(insn);
                if (next_arg_optional) {
                    next_arg_optional = false;
                    if (argString.empty()) continue;
                }
                if (i != 0) s += ", ";
                s += argString;
            }
        }
        return s;
    }

    uint32_t get_match() const { return match; }
    uint32_t get_mask() const { return mask; }

private:
    uint32_t match;
    uint32_t mask;
    std::vector<const arg_t*> args;
    std::string name;
};

class disassembler_t
{
public:
    disassembler_t(const uint64_t xlen);
    ~disassembler_t();

    std::string disassemble(insn_t insn) const;
    const disasm_insn_t* lookup(insn_t insn) const;

    void add_insn(disasm_insn_t* insn);

private:
    static const int HASH_SIZE = 255;
    std::vector<const disasm_insn_t*> chain[HASH_SIZE + 1];

    void add_instructions(const uint64_t isa);

    const disasm_insn_t* probe_once(insn_t insn, size_t idx) const;

    static const unsigned int MASK1 = 0x7f;
    static const unsigned int MASK2 = 0xe003;

    static unsigned int hash(insn_bits_t insn, unsigned int mask)
    {
        return (insn & mask) % HASH_SIZE;
    }
};

#endif
