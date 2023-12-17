#include <iostream>
#include <fstream>
#include <string>
#include <stdint.h>

#include "define.hpp"
#include "flags.hpp"


class MemSim {
public:
    uint64_t pmem_size = 24 * 1024 * 1024; // 24M size
    char *pmem;

    MemSim() {
        pmem = new char[pmem_size];
    }
    void loadBinary(std::string path) {
        std::string workload_path = path;
        std::ifstream workload_fs(workload_path, std::ios::in | std::ios::binary);
        if (workload_fs.is_open())
        {
            std::cout << "load binary file to rom" << std::endl;
            workload_fs.seekg(0, workload_fs.end);
            uint64_t filesize = workload_fs.tellg();
            workload_fs.seekg(0, workload_fs.beg);
            workload_fs.read(pmem, filesize);
            workload_fs.close();
            std::cout << "execute binary file size: " << filesize << std::endl;
            std::cout << "load successed" << std::endl;
        }
        else
        {
            throw std::invalid_argument("can't open file: " + workload_path + "\n");
        }
    }
    char readByte(uint64_t addr) {
        if (addr < pmem_size) {
            unsigned char a;
            a = pmem[addr];
            return a;
        }
        return 0;
    }
}memSim;


void init_workload(std::string path) {
    memSim.loadBinary(path);
}


char* get_pmem(uint64_t& size) {
    size = memSim.pmem_size;
    return memSim.pmem;
}

extern "C" char read_rom(uint64_t addr) {
    uint64_t paddr = addr - PMEM_BASE;
    unsigned char byte = memSim.readByte(paddr);
    DPRINTF(ROM, "read rom addr: %lx, data: %#02x\n", addr, byte);
    return byte;
}







