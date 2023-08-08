#include <iostream>
#include <map>

std::map<const char*,uint64_t> statsPerf;


extern "C" void perfAccumulate(const char* name, uint64_t val) {
    statsPerf[name] += val;
}




