#include <iostream>
#include "dpic_util.hpp"


uint64_t workload_size=0;
char *workload_binary=nullptr;

extern "C" bool vassert(bool a) {
    
}

extern "C" bool check_flag(uint32_t flag) {
    return true;
}

extern "C" char read_rom(uint64_t addr) {
    if (addr < workload_size) {
        unsigned char a;
        a = workload_binary[addr];
        return a;
    }
    return 0;
}


