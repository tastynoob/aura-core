#include "dpic_util.hpp"



void diff_init() {

}


const CData *arch_int_renameMapping;
extern "C" void register_int_archRenameMapping(const svOpenArrayHandle map) {
    arch_int_renameMapping = ((VlUnpacked<CData, 32>*)map)->m_storage;
}










