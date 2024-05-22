#include <iostream>
#include <fstream>
#include <ostream>
#include <map>
#include "riscv-disasm/disasm.h"
#include "statistics.hpp"
#include "debugflags.hpp"
using namespace std;

std::map<const char*,uint64_t> statsPerf;
std::map<const char*,uint64_t> avgStatsPerf;
std::map<const char*,std::map<uint64_t, uint64_t>> diststatsPerf;
disassembler_t* disasm = new disassembler_t(64);

void dumpStats() {
    ofstream fs("stats.txt",std::ios::out);
    for (auto it = statsPerf.begin(); it != statsPerf.end();it++) {
        fs << it->first << " : " << it->second << "\n";
    }
    for (auto it = avgStatsPerf.begin(); it != avgStatsPerf.end();it++) {
        fs << it->first << " : " << (float)it->second/(curTick()/2) << "\n";
    }
    for (auto it = diststatsPerf.begin(); it != diststatsPerf.end();it++) {
        for (auto it2 = it->second.begin(); it2 != it->second.end();it2++) {
            fs << it->first << "::";
            fs << it2->first << " : " << it2->second << "\n";
        }
    }

    fs.close();
}

void InstMeta::print()
{
    DPRINTF(PIPELINE, "%s %s F%lu ", base().c_str(), disassembly().c_str(), active_tick[AT_fetch]/2);
    for (int i=InstPos::AT_fetch; i<InstPos::AT_wb; i++) {
        assert(active_tick[i+1] >= active_tick[i]);
        uint64_t cycle = (active_tick[i+1] - active_tick[i]) / 2;
        DPRINTFD(PIPELINE, "%lu:", cycle);
    }
    DPRINTFD(PIPELINE, "C\n");
}

std::string InstMeta::disassembly()
{
    if (cachedDisasm.empty()) {
        cachedDisasm = disasm->disassemble(code);
    }
    return cachedDisasm;
}


#define MAX_INSTMETA_NUM 300
class InstMonitor {
    uint64_t seq_acc = 0;
    std::vector<InstMeta*> insts;
    public:
    InstMonitor() {
        insts.resize(MAX_INSTMETA_NUM, nullptr);
    }

    uint64_t hash(uint64_t seq) {
        return seq % MAX_INSTMETA_NUM;
    }

    InstMeta* create() {
        InstMeta* inst = new InstMeta();
        inst->seq = seq_acc;
        if (insts[hash(inst->seq)] != nullptr) {
            delete insts[hash(inst->seq)];
        }
        insts[hash(inst->seq)] = inst;
        inst->it = insts.begin() + hash(inst->seq);
        seq_acc++;
        return inst;
    }
    InstMeta* read_by_seq(uint64_t seq) {
        return insts[hash(seq)];
    }

}instMonitor;

InstMeta* read_instmeta(uint64_t seq) {
    InstMeta* instmeta = instMonitor.read_by_seq(seq);
    assert(instmeta);
    auto it = *(instmeta->it);
    assert(it->seq == instmeta->seq);
    return it;
}


void perfAccumulate(const char* name, uint64_t val) {
    statsPerf[name] = statsPerf[name] + val;
}

void perfAvgAccumulate(const char* name, uint64_t val) {
    avgStatsPerf[name] = avgStatsPerf[name] + val;
}

void perfDistAccumulate(const char* name, uint64_t key, uint64_t val) {
    diststatsPerf[name][key] = diststatsPerf[name][key] + val;
}

extern "C" {
    void cycle_step() {
        perfAccumulate("runningCycles", 1);
    }

    uint64_t build_instmeta(uint64_t pc, uint64_t inst_code) {
        auto inst = instMonitor.create();
        inst->code = inst_code;
        inst->pc = pc;
        inst->active_tick[InstPos::AT_fetch] = curTick();
        DPRINTF(FETCH, "%s build inst code: %08lx\n", inst->base().c_str(), inst_code);
        return inst->seq;
    }

    //
    void update_instMeta(uint64_t instmeta, uint64_t key, uint64_t value) {
        InstMeta* inst = read_instmeta(instmeta);
        assert(key < MetaKeys::NUM_META);
        inst->meta[key] = value;
    }

    //
    void update_instPos(uint64_t instmeta, uint64_t pos) {
        InstMeta* inst = read_instmeta(instmeta);
        assert(pos < InstPos::NUMPOS);
        inst->pos[pos] = true;
        inst->active_tick[pos] = curTick();
        switch (pos)
        {
        case InstPos::AT_decode:
            DPRINTF(DECODE, "%s was decoded is %s\n", inst->base().c_str(), inst->disassembly().c_str());
            break;
        case InstPos::AT_rename:
            DPRINTF(RENAME, "%s was renamed\n", inst->base().c_str());
            if (inst->meta[MetaKeys::META_ISMV]) {
                for (int i=InstPos::AT_rename + 1;i<=InstPos::AT_wb; i++) {
                    inst->active_tick[i] = inst->active_tick[InstPos::AT_rename] + 2;
                }
            }
            break;
        case InstPos::AT_dispQue:
            break;
        case InstPos::AT_issueQue:
            DPRINTF(EXECUTE, "%s dispatch to issueQue\n", inst->base().c_str());
            break;
        case InstPos::AT_fu:
            DPRINTF(EXECUTE, "%s start executing\n", inst->base().c_str());
            break;
        case InstPos::AT_wb:
            DPRINTF(EXECUTE, "%s writeback\n", inst->base().c_str());
            break;
        default:
            break;
        }
    }
}




extern "C" {
    void ubtb_loookup(uint64_t lookup_pc, uint64_t endAddr, uint64_t targetAddr, uint64_t hit, uint64_t taken, uint64_t index) {
        if (hit) {
            DPRINTF(UBTB, "ubtb hit index %d [%lx : %lx) -> %lx\n", index, lookup_pc, endAddr, taken ? targetAddr : endAddr);
        }
        else {
            DPRINTF(UBTB, "ubtb miss index %d %lx\n", index, lookup_pc);
        }
    }

    void ubtb_update_new_block(uint64_t uindex, uint64_t startAddr, uint64_t fallthru, uint64_t target, uint64_t scnt) {
        DPRINTF(UBTB, "update new block uindex %ld [%lx : %lx) tar> %lx scnt %lu\n", uindex, startAddr, fallthru, target, scnt);
    }

    void ftb_update_new_block(uint64_t startAddr, uint64_t fallthru, uint64_t target) {
        DPRINTF(FTB, "update new block [%lx : %lx) tar> %lx\n", startAddr, fallthru, target);
    }

    void bpu_update_arch_gbh(const svLogicVecVal* gbr, uint64_t len) {
        char buf[512];
        for (int i=0; i<len; i++) {
            uint32_t bit = (gbr[i / 32].aval >> (i%32)) & 0x1;
            buf[i] = bit + '0';
        }
        buf[len] = 0;
        DPRINTF(BPU_GBH, "arch gbh: >%s\n", buf);
    }
    void bpu_update_spec_gbh(const svLogicVecVal* gbr, uint64_t len, uint64_t squash) {
        char buf[512];
        for (int i=0; i<len; i++) {
            uint32_t bit = (gbr[i / 32].aval >> (i%32)) & 0x1;
            buf[i] = bit + '0';
        }
        buf[len] = 0;
        DPRINTF(BPU_GBH, "spec gbh: >%s%s\n", buf, squash ? " squash" : "");
    }

    void bpu_predict_block(uint64_t startAddr, uint64_t endAddr, uint64_t nextAddr, uint64_t select) {
        const char* dst = select == 0 ? "none" :
                          select == 1 ? "ubtb" :
                          "none";
        DPRINTF(BPU, "bpu predict block [%lx : %lx) -> %lx by %s\n", startAddr, endAddr, nextAddr, dst);
    }

    void ftq_commit(
        uint64_t startAddr,
        uint64_t endAddr,
        uint64_t targetAddr,
        uint64_t taken,
        uint64_t branchType
    ) {
        char* btype[] = {
            "none",
            "cond",
            "direct",
            "indirect",
            "call",
            "ret"
        };
        DPRINTF(FTQCOMMIT, "bpu commit [%lx : %lx) tar> %lx taken: %ld, btype: %s\n",
                startAddr, endAddr, targetAddr, taken, btype[branchType]);
    }

    void ftq_writeback(
        uint64_t startAddr,
        uint64_t endAddr,
        uint64_t targetAddr,
        uint64_t mispred,
        uint64_t taken,
        uint64_t branchType
    ) {
        char* btype[] = {
            "none",
            "cond",
            "direct",
            "indirect",
            "call",
            "ret"
        };
        DPRINTF(FTQ, "bru writeTo FTQ [%lx : %lx) tar> %lx by %s mispred: %lx, taken: %lx\n",
                startAddr, endAddr, targetAddr, btype[branchType], mispred, taken);
    }

    void fetch_block(uint64_t startAddr, uint64_t endAddr, uint64_t nextAddr, uint64_t predEndAddr, uint64_t predNextAddr, uint64_t falsepred) {
        DPRINTF(FETCH, "fetch block [%lx : %lx) -> %lx", startAddr, endAddr, nextAddr);
        if (falsepred) {
            DPRINTFD(FETCH, " falsepred [%lx : %lx) -> %lx", startAddr, predNextAddr, predNextAddr);
        }
        DPRINTFD(FETCH, "\n");
    }

    void rename_alloc(uint64_t seq, uint64_t logic_idx, uint64_t physcial_idx, uint64_t ismv) {
        InstMeta* inst = read_instmeta(seq);
        if (ismv) {
            DPRINTF(RENAME_ALLOC, "%s rename move eliminate x%lu -> p%lu\n", inst->base().c_str(), logic_idx, physcial_idx);
        }
        else {
            DPRINTF(RENAME_ALLOC, "%s rename alloc x%lu -> p%lu\n", inst->base().c_str(), logic_idx, physcial_idx);
        }
    }

    void rename_dealloc(uint64_t physcial_idx) {
        DPRINTF(RENAME_ALLOC, "rename dealloc p%lu\n", physcial_idx);
    }

    void dispatch_stall(uint64_t reason) {
        if (reason == 0) { // rob full
            perfAccumulate("dispatchStall:rob full (cycle)", 1);
        }
        else if (reason == 1) { // immbuffer full
            perfAccumulate("dispatchStall:immbuffer full (cycle)", 1);
        }
        else if (reason == 2) { // intDQ full
            perfAccumulate("dispatchStall:intDQ full (cycle)", 1);
        }
        else {
            perfAccumulate("dispatchStall:other (cycle)", 1);
        }
    }

    void goto_fu(uint64_t instmeta, uint64_t fu_id) {
        InstMeta* inst = read_instmeta(instmeta);
        DPRINTF(EXECUTE, "%s going to fu %lu\n", inst->base().c_str(), fu_id);
    }

    void cpu_stucked(uint64_t seqNum, uint64_t vld) {
        DPRINTFA("cpu stucked!!\n")
        if (vld) {
            InstMeta* inst = read_instmeta(seqNum);
            DPRINTFA("stucked inst: %s %s\n", inst->base().c_str(), inst->disassembly().c_str());
        }
        mark_exit(true);
    }

    void squash_pipe(uint64_t isMispred, uint64_t isViolation) {
        if (isMispred)
            DPRINTF(COMMIT, "squash due to mispred\n");
        if (isViolation)
            DPRINTF(COMMIT, "squash due to violation\n");
    }

    void loadQue_write(uint64_t vaddr, uint64_t size, uint64_t lqIdx) {
        DPRINTF(LDQUE, "loadQue entry%lu [addr: %#lx size: %#lx]\n", lqIdx, vaddr, size);
    }

    void storeQue_write_addr(uint64_t vaddr, uint64_t size, uint64_t sqIdx) {
        DPRINTF(STQUE, "storeQue'addr entry%lu [addr: %#lx size: %#lx]\n", sqIdx, vaddr, size);
    }

    void storeQue_write_data(uint64_t data, uint64_t sqIdx) {
        DPRINTF(STQUE, "storeQue'data entry%lu [data: %#lx]\n", sqIdx, data);
    }

    void memory_violation_find(uint64_t ldpc, uint64_t stpc) {
        DPRINTF(MEMDEP, "find violation: loadpc: %#lx -> storepc: %#lx\n", ldpc, stpc);
    }

    void commit_idle(uint64_t c) {
        perfAccumulate("commitIdle (cycle)", c);
    }

    void committed_loads_stores(uint64_t lds, uint64_t sts) {
        perfAccumulate("committedLoads", lds);
        perfAccumulate("committedStoress", lds);
    }

    void count_memory_violation() {
        perfAccumulate("memoryViolation", 1);
    }

    void bp_hit_at(uint64_t i) {
        // 1: ubtb
        switch (i)
        {
        case 1:
            perfAccumulate("bp hit::ubtb", 1);
            break;
        default:
            break;
        }
    }

    void count_falsepred(uint64_t n) {
        perfAccumulate("BPU falsepred:", n);
    }

    void count_bpuGeneratedBlock(uint64_t n) {
        perfAvgAccumulate("avg BPU predicted block size to backend per cycle (byte)", n);
    }

    void count_regfilewrite(uint64_t n) {
        perfDistAccumulate("regfile write", n, 1);
    }

    void count_fetchToBackend(uint64_t n) {
        perfAvgAccumulate("avg fetchedInsts to backend per cycle", n);
        perfDistAccumulate("fetchedInsts to backend", n, 1);
    }
}