#include <iostream>
#include <fstream>
#include <ostream>
#include <map>
#include "statistics.hpp"
#include "flags.hpp"
using namespace std;

std::map<const char*,uint64_t> statsPerf;
std::map<const char*,uint64_t> avgStatsPerf;

void dumpStats() {
    ofstream fs("stats.txt",std::ios::out);
    for (auto it = statsPerf.begin(); it != statsPerf.end();it++) {
        fs << it->first << " : " << it->second << "\n";
    }
    for (auto it = avgStatsPerf.begin(); it != avgStatsPerf.end();it++) {
        fs << it->first << " : " << (float)it->second/(curTick()/2) << "\n";
    }

    fs.close();
}

void InstMeta::print()
{
    char c;
    DPRINTF(PIPELINE, "%s ", base().c_str());
    for (int i=InstPos::AT_fetch; i<InstPos::AT_wb; i++) {
        c = '0' + i - InstPos::AT_fetch;
        assert(active_tick[i+1] >= active_tick[i]);
        uint64_t cycle = (active_tick[i+1] - active_tick[i]) / 2;
        for (int j=0;j<cycle;j++) {
            DPRINTD(PIPELINE, "%c", c);
        }
    }
    DPRINTD(PIPELINE, "C\n");
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

extern "C" {
    void cycle_step() {
        perfAccumulate("runningCycles", 1);
    }

    uint64_t build_instmeta(uint64_t pc, uint64_t inst_code) {
        auto inst = instMonitor.create();
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
            DPRINTF(DECODE, "%s was decoded is %s\n", inst->base().c_str(),
            inst->meta[MetaKeys::META_ISBRANCH] ? "branch" :
            inst->meta[MetaKeys::META_ISLOAD] ? "load" :
            inst->meta[MetaKeys::META_ISSTORE] ? "store" :
            "dontCare"
            );
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
            break;
        case InstPos::AT_fu:
            DPRINTF(EXECUTE, "%s start executing\n", inst->base().c_str());
        default:
            break;
        }
    }
}




extern "C" {
    void ftb_update_new_block(uint64_t startAddr, uint64_t fallthru, uint64_t target) {
        DPRINTF(FTB, "update new block [%lx : %lx) tar> %lx\n", startAddr, fallthru, target);
    }

    void bpu_predict_block(uint64_t startAddr, uint64_t endAddr, uint64_t nextAddr, uint64_t use_ftb) {
        DPRINTF(BPU, "bpu predict block [%lx : %lx) -> %lx by %s\n", startAddr, endAddr, nextAddr, use_ftb ? "FTB" : "NONE");
    }

    void fetch_block(uint64_t startAddr, uint64_t endAddr, uint64_t nextAddr, uint64_t falsepred) {
        DPRINTF(FETCH, "fetch block [%lx : %lx) -> %lx%s\n", startAddr, endAddr, nextAddr, (falsepred ? " falsepred" : ""));
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

    void squash_pipe(uint64_t isMispred) {
        DPRINTF(COMMIT, "squash due to %s\n", "mispred");
    }

    void commit_idle(uint64_t c) {
        perfAccumulate("commitIdle (cycle)", c);
    }
}

extern "C" {
    void count_bpuGeneratedBlock(uint64_t n) {
        perfAvgAccumulate("avg BPU predicted block size to backend per cycle (byte)", n);
    }

    void count_fetchToBackend(uint64_t n) {
        perfAvgAccumulate("avg fetchedInsts to backend per cycle", n);
        switch (n)
        {
        case 0:
            perfAccumulate("fetchedInsts to backend::0 (cycle)", 1);
            break;
        case 1:
            perfAccumulate("fetchedInsts to backend::1 (cycle)", 1);
            break;
        case 2:
            perfAccumulate("fetchedInsts to backend::2 (cycle)", 1);
            break;
        case 3:
            perfAccumulate("fetchedInsts to backend::3 (cycle)", 1);
            break;
        case 4:
            perfAccumulate("fetchedInsts to backend::4 (cycle)", 1);
            break;
        case 5:
            perfAccumulate("fetchedInsts to backend::5 (cycle)", 1);
            break;
        case 6:
            perfAccumulate("fetchedInsts to backend::6 (cycle)", 1);
            break;
        case 7:
            perfAccumulate("fetchedInsts to backend::7 (cycle)", 1);
            break;
        case 8:
            perfAccumulate("fetchedInsts to backend::8 (cycle)", 1);
            break;
        case 9:
            perfAccumulate("fetchedInsts to backend::9 (cycle)", 1);
            break;
        case 10:
            perfAccumulate("fetchedInsts to backend::10 (cycle)", 1);
            break;
        case 11:
            perfAccumulate("fetchedInsts to backend::11 (cycle)", 1);
            break;
        case 12:
            perfAccumulate("fetchedInsts to backend::12 (cycle)", 1);
            break;
        default:
            assert(false);
            break;
        }
    }
}