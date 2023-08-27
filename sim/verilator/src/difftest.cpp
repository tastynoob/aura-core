#include "dpic_util.hpp"


int rename_mapping[32] = {0};
uint64_t arch_int_regfile[32] = {0};


void diff_init() {

}



extern "C" void rename_intmap(const uint32_t lrd, const uint32_t prd) {
    assert(lrd<32 && lrd !=0);
    rename_mapping[lrd] = prd;
}

extern "C" void write_regfile(const uint32_t lrd, const uint32_t ismv, const uint64_t val) {
    
}










