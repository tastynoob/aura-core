#include <iostream>
#include <fstream>
#include <ostream>
#include <map>
#include "statistics.hpp"
using namespace std;

std::map<string,uint64_t> statsPerf;

void dumpStats() {
    ofstream fs("stats.txt",std::ios::out);
    for (auto it = statsPerf.begin(); it != statsPerf.end();it++) {
        fs << it->first << " : " << it->second << "\n";
    }
    fs.close();
}



class InstMonitor {
    std::list<InstMeta*> insts;

    InstMeta* create() {
        insts.push_back(new InstMeta());
        insts.back()->it = (--insts.end());
        return insts.back();
    }

    void retire(InstMeta* inst) {
        insts.erase(inst->it);
        delete inst;
    }
};



void InstMeta::print()
{
}


extern "C" void perfAccumulate(const char* name, uint64_t val) {
    string na = name;
    statsPerf[na] = statsPerf[na] + val;
}


extern "C" {
    void update_instMeta(uint64_t ptr, std::string msg) {
        
    }
}