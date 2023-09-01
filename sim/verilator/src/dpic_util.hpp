#include <iostream>
#include <fstream>
#include <verilated.h>
#include <svdpi.h>


extern uint64_t workload_size;
extern char *workload_binary;

void dumpStats();