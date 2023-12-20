#include <iostream>
#include <stdint.h>
#include <dlfcn.h>
#include <err.h>
#include <verilated.h>
#include <svdpi.h>

#include "define.hpp"
#include "flags.hpp"
#include "statistics.hpp"

enum DEST_TYPE {
    INT,
    FP
};

enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };


struct riscv64_CPU_regfile
{
    union
    {
      uint64_t _64;
    } gpr[32];

    union
    {
      uint64_t _64;
    } fpr[32];

    // shadow CSRs for difftest
    uint64_t mode;
    uint64_t mstatus, sstatus;
    uint64_t mepc, sepc;
    uint64_t mtval, stval;
    uint64_t mtvec, stvec;
    uint64_t mcause, scause;
    uint64_t satp;
    uint64_t mip, mie;
    uint64_t mscratch, sscratch;
    uint64_t mideleg, medeleg;
    uint64_t pc;

    uint64_t& operator[](int x) {
        assert(x<64);
        return ((uint64_t*)this)[x];
    }
};

class RefProxy
{
  public:
    // public callable functions
    void (*memcpy)(uint64_t nemu_addr, void *dut_buf, size_t n,
                   bool direction) = nullptr;
    void (*regcpy)(void *dut, bool direction) = nullptr;
    void (*csrcpy)(void *dut, bool direction) = nullptr;
    void (*uarchstatus_cpy)(void *dut, bool direction) = nullptr;
    int (*store_commit)(uint64_t *saddr, uint64_t *sdata,
                        uint8_t *smask) = nullptr;
    void (*exec)(uint64_t n) = nullptr;
    uint64_t (*guided_exec)(void *disambiguate_para) = nullptr;
    uint64_t (*update_config)(void *config) = nullptr;
    void (*raise_intr)(uint64_t no) = nullptr;
    void (*isa_reg_display)() = nullptr;
    void (*query)(void *result_buffer, uint64_t type) = nullptr;
    void (*debug_mem_sync)(uint64_t addr, void *bytes, size_t size) = nullptr;
    void (*sdcard_init)(const char *img_path,
                        const char *sd_cpt_bin_path) = nullptr;
} refProxy;

class DiffState {
    public:
    bool enable_diff = false;
    uint64_t ref_this_pc;
    uint64_t ref_next_pc;
    riscv64_CPU_regfile* ref_reg;
    DiffState() : ref_reg(new riscv64_CPU_regfile){}
} diffState;


extern char* get_pmem(uint64_t& size);

void diff_init(const char* ref_path) {
    void* handle = dlmopen(LM_ID_NEWLM, ref_path, RTLD_LAZY | RTLD_DEEPBIND);
    printf("Using %s for difftest\n", ref_path);
    if (!handle) {
        printf("%s\n", dlerror());
        exit(1);
    }

    refProxy.memcpy = (void (*)(uint64_t, void *, size_t, bool))dlsym(
        handle, "difftest_memcpy");
    assert(refProxy.memcpy);

    refProxy.regcpy = (void (*)(void *, bool))dlsym(handle, "difftest_regcpy");
    assert(refProxy.regcpy);

    refProxy.csrcpy = (void (*)(void *, bool))dlsym(handle, "difftest_csrcpy");
    assert(refProxy.csrcpy);

    refProxy.uarchstatus_cpy =
        (void (*)(void *, bool))dlsym(handle, "difftest_uarchstatus_sync");
    assert(refProxy.uarchstatus_cpy);

    refProxy.exec = (void (*)(uint64_t))dlsym(handle, "difftest_exec");
    assert(refProxy.exec);

    refProxy.guided_exec = (uint64_t(*)(void *))dlsym(handle, "difftest_guided_exec");
    assert(refProxy.guided_exec);

    refProxy.update_config = (uint64_t(*)(void *))dlsym(handle, "update_dynamic_config");
    assert(refProxy.update_config);

    refProxy.store_commit = (int (*)(uint64_t *, uint64_t *, uint8_t *))dlsym(
        handle, "difftest_store_commit");
    assert(refProxy.store_commit);

    refProxy.raise_intr = (void (*)(uint64_t))dlsym(handle, "difftest_raise_intr");
    assert(refProxy.raise_intr);

    refProxy.isa_reg_display = (void (*)(void))dlsym(handle, "isa_reg_display");
    assert(refProxy.isa_reg_display);

    auto nemu_difftest_set_mhartid =
        (void (*)(int))dlsym(handle, "difftest_set_mhartid");

    nemu_difftest_set_mhartid(0);

    auto nemu_init = (void (*)(void))dlsym(handle, "difftest_init");
    assert(nemu_init);

    nemu_init();
    diffState.enable_diff = true;

    printf("start memcpy to ref\n");
    uint64_t size;
    char* pmem = get_pmem(size);
    refProxy.memcpy(PMEM_BASE, pmem, size, DIFFTEST_TO_REF);

    refProxy.regcpy(diffState.ref_reg, DIFFTEST_TO_DUT);
    diffState.ref_reg->pc = PMEM_BASE;
    refProxy.regcpy(diffState.ref_reg, DIFFTEST_TO_REF);
    refProxy.regcpy(diffState.ref_reg, DIFFTEST_TO_DUT);
    assert((uint64_t)diffState.ref_reg->pc == PMEM_BASE);
}

extern void mark_next_cycle_fail();

int arch_int_renameMapping[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
uint64_t physical_int_regfile[200] = {0};

uint64_t arch_readIntReg(int index) {
    int physic_index = arch_int_renameMapping[index];
    assert(physic_index >= 0 && physic_index < 200);
    return physical_int_regfile[physic_index];
}

uint64_t arch_readCSRReg(int index) {
    return 0;
}


void display_reg() {
    printf("********** dump aura regfile **********\n");
    for (int i = 0; i < 32; i ++) {
        printf(" x%02d: %016lx", i, arch_readIntReg(i));
        if (i % 4 == 3) {
            printf("\n");
        }
    }
}



extern "C" void arch_commitInst(
    const uint64_t dst_type,
    const uint64_t logic_idx,
    const uint64_t physic_idx,
    const uint64_t instmeta_ptr) {
    // update arch rename mapping
    assert(logic_idx < 32);
    if (!diffState.enable_diff) {
        return;
    }
    arch_int_renameMapping[logic_idx] = physic_idx;
    diffState.ref_this_pc = diffState.ref_reg->pc;
    refProxy.exec(1);
    refProxy.regcpy(diffState.ref_reg, DIFFTEST_TO_DUT);
    diffState.ref_next_pc = diffState.ref_reg->pc;

    InstMeta* inst = read_instmeta(instmeta_ptr);

    DPRINTF(COMMIT, "%s commit\n", inst->base().c_str());

    bool difftest_failed = false;
    if (inst->pc != diffState.ref_this_pc) {
        printf("diff at pc, this: %lx, ref: %lx\n", inst->pc, diffState.ref_this_pc);
        difftest_failed = true;
    }
    if (inst->meta[MetaKeys::META_ISBRANCH]) {
        if (inst->meta[MetaKeys::META_NPC] != diffState.ref_next_pc) {
            printf("diff at npc, this: %lx, ref: %lx\n", inst->meta[MetaKeys::META_NPC], diffState.ref_next_pc);
            difftest_failed = true;
        }
    }

    if (logic_idx != 0) {
        uint64_t aura_val, ref_val;
        const char* str = "none";
        if (dst_type == DEST_TYPE::INT) {
            aura_val = arch_readIntReg(logic_idx);
            ref_val = diffState.ref_reg->gpr[logic_idx]._64;
            str = "x";
        }
        if (aura_val != ref_val) {
            printf("diff at reg %s%lu, this: %lx, ref: %lx\n", str, logic_idx, aura_val, ref_val);
            difftest_failed = true;
        }
    }
    if (difftest_failed) {
        printf("difftest failed!\n");\
        fflush(stdout);
        refProxy.isa_reg_display();
        display_reg();
        mark_next_cycle_fail();
        diffState.enable_diff = false;
        debugChecker.clearFlags();
    }
}

extern "C" void write_int_physicRegfile(uint64_t idx, uint64_t value) {
    assert(idx < 200);
    physical_int_regfile[idx] = value;
}










