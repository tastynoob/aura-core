#pragma once
#include <bits/stdc++.h>
#include <format>

#include <verilated.h>
#include <svdpi.h>

extern uint64_t curTick();

enum InstPos {
    AT_fetch,
    AT_decode,
    AT_rename,
    AT_dispQue,
    AT_issueQue,
    AT_fu,
    AT_lq,
    AT_sq,
    NUMPOS
};

enum MetaKeys {
    META_ISBRANCH,
    META_ISLOAD,
    META_ISSTORE,
    META_MISPRED,// branch only
    META_NPC,// branch only
    META_VADDR,// load/store only
    META_PADDR,// load/store only
    NUM_META
};

struct InstMeta
{
    uint64_t seq = ~0;
    uint64_t pc = ~0;
    
    // pos
    uint64_t issue_tick = ~0;
    uint64_t finished_tick = ~0;
    uint64_t commit_tick = ~0;
    uint64_t ready_tick = ~0;
    bool is_first_issue = false;
    std::vector<bool> pos;
    std::vector<uint64_t> active_tick;

    // meta
    std::vector<uint64_t> meta;

    std::vector<InstMeta*>::iterator it;
    InstMeta() : pos(InstPos::NUMPOS, false), active_tick(InstPos::NUMPOS, 0), meta(MetaKeys::NUM_META, 0) {}

    std::string base() { return std::format("[sn {:d} pc {:x}]", seq, pc); }

    void print();
};



void dumpStats();

InstMeta* read_instmeta(uint64_t ptr);




