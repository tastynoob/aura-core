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

class InstMonitor {
    uint64_t seq_acc = 0;
    std::list<InstMeta*> insts;
    public:
    InstMeta* create() {
        insts.push_back(new InstMeta());
        insts.back()->it = (--insts.end());
        if (insts.size() > 500) {
            insts.pop_front();
        }
        insts.back()->seq = seq_acc;
        seq_acc++;
        return insts.back();
    }
}instMonitor;

InstMeta* read_instmeta(uint64_t ptr) {
    InstMeta* instmeta = (InstMeta*)ptr;
    auto it = *(instmeta->it);
    assert(it->seq != ~0);
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
        DPRINTF(FETCH, "%s build inst code: %08lx, instmeta ptr: %p\n", inst->base().c_str(), inst_code, inst);
        return (uint64_t)inst;
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
            "undefined"
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

extern "C" bool vassert(bool a) {
    return false;
}

extern "C" bool check_flag(uint32_t flag) {
    return true;
}


