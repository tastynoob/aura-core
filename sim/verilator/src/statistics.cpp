#include <iostream>
#include <fstream>
#include <ostream>
#include <map>
#include "svdpi.h"
using namespace std;

std::map<string,uint64_t> statsPerf;

void dumpStats() {
    ofstream fs("stats.txt",std::ios::out);
    for (auto it = statsPerf.begin(); it != statsPerf.end();it++) {
        fs << it->first << " : " << it->second << "\n";
    }
    fs.close();
}


extern "C" void perfAccumulate(const char* name, uint64_t val) {
    string na = name;
    statsPerf[na] = statsPerf[na] + val;
}




