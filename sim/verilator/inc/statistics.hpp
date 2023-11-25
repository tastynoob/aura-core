#include <bits/stdc++.h>

#include <verilated.h>
#include <svdpi.h>

extern uint64_t curTick();



enum InstPos {
    AT_fetchQue,
    AT_decode,
    AT_rename,
    AT_dispQue,
    AT_issueQue,
    AT_fu,
    AT_lq,
    AT_sq,
    NUMPOS
};

struct InstMeta
{
    uint64_t seq;
    uint64_t pc;

    uint64_t fetch_tick;
    uint64_t decode_tick;
    uint64_t rename_tick;
    uint64_t dispatch_tick;
    uint64_t ready_tick;
    bool is_first_issue = false;
    uint64_t issue_tick;
    uint64_t execute_tick;
    uint64_t finished_tick;
    uint64_t commit_tick;

    std::vector<bool> pos;

    std::list<InstMeta*>::iterator it;
    InstMeta() : pos(InstPos::NUMPOS, false) {}

    void print();
};








