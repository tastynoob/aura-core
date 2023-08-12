#include <iostream>
#include "dpic_util.hpp"



std::ifstream *workload_fs;


extern "C" bool check_flag(uint32_t flag) {
    return true;
}

extern "C" char read_rom(uint64_t addr) {
    if (workload_fs) {
        char a;
        workload_fs->seekg(addr);
        workload_fs->read(&a,1);
        return a;
    }
    return 0;
}







