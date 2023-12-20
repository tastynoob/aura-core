#include <iostream>
#include <fstream>
#include <ostream>
#include <map>
#include "statistics.hpp"
#include "flags.hpp"
using namespace std;

std::map<string,uint64_t> statsPerf;

void dumpStats() {
    ofstream fs("stats.txt",std::ios::out);
    for (auto it = statsPerf.begin(); it != statsPerf.end();it++) {
        fs << it->first << " : " << it->second << "\n";
    }
    fs.close();
}

void InstMeta::print()
{
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


extern "C" void perfAccumulate(const char* name, uint64_t val) {
    string na = name;
    statsPerf[na] = statsPerf[na] + val;
}


extern "C" {
    uint64_t build_instmeta(uint64_t pc, uint64_t inst_code) {
        auto inst = instMonitor.create();
        inst->pc = pc;
        inst->active_tick[InstPos::AT_fetch] = curTick();
        DPRINTF(FETCH, "%s build inst code: %08lx, instmeta ptr: %lu\n", inst->base().c_str(), inst_code, inst->seq);
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
            break;
        case InstPos::AT_fu:
            DPRINTF(EXECUTE, "%s start executing\n", inst->base().c_str());
        default:
            break;
        }
    }
}

extern "C" {
    void goto_fu(uint64_t instmeta, uint64_t fu_id) {
        InstMeta* inst = read_instmeta(instmeta);
        DPRINTF(EXECUTE, "%s going to fu %lu\n", inst->base().c_str(), fu_id);
    }
}

