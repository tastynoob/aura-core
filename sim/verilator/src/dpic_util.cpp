#include <iostream>
#include "dpic_util.hpp"


uint64_t workload_size;
char *workload_binary;

extern "C" bool check_flag(uint32_t flag) {
    return true;
}

extern "C" char read_rom(uint64_t addr) {
    if (addr < workload_size) {
        char a;
        a = workload_binary[addr];
        return a;
    }
    return 0;
}







