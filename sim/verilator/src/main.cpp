#include <verilated.h>
#include <verilated_vcd_c.h>
#include <string>
#include "Vtb.h"
#include "cmdline.hpp"
#include "dpic_util.hpp"

uint64_t max_simTime = 1000;
uint64_t main_time = 0;
VTOP *top;

char buffer[100];

int main(int argc, char **argv)
{
    for (int i=0;i<argc;i++) {
        std::cout << argv[i] << " ";
    }
    std::cout << std::endl;
    cmdline::parser parser;
    parser.add<std::string>("exec-file", 'f', "the riscv executable binary file path", false);
    parser.add<std::string>("end", 'e', "end simulation by specific conditions\n"
                                        "       e.g\n"
                                        "           -e i100t25\n"
                                        "       end simulation at 100th instruction or 25th tick",
                            false);
    parser.add<uint32_t>("seed", 's', "the seed of x-assign random init", false);
#ifdef USE_TRACE
    parser.add<std::string>("trace", 0, "enable trace by specific conditions\n"
                                        "       e.g\n"
                                        "           --trace i100t25\n"
                                        "       enable trace starting at 100th instruction or 25th tick",
                            false);
#endif
    parser.parse_check(argc, argv);
        std::cout << parser.get<std::string>("end") << std::endl;
    if (parser.exist("exec-file"))
    {
        std::string workload_path = parser.get<std::string>("exec-file");
        std::ifstream workload_fs(workload_path, std::ios::in | std::ios::binary);
        if (workload_fs.is_open()) {
            workload_fs.seekg(0, workload_fs.end);
            uint64_t filesize = workload_fs.tellg();
            workload_binary = new char[filesize];
            workload_fs.read(workload_binary, filesize);
            workload_fs.close();
        }
        else {
            throw "can't open file: " + workload_path + "\n";
        }
    }

    int verilated_seed = time(0);
    if (parser.exist("seed"))
    {
        verilated_seed = parser.get<int>("seed");
    }

    int verilated_argc = 3;
    char const *verilated_argv[3];
    sprintf(buffer, "+verilator+seed+%d", verilated_seed);
    // veriator simulate runtime args
    verilated_argv[0] = argv[0];
    verilated_argv[1] = buffer;
    verilated_argv[2] = "+verilator+rand+reset+2";
    Verilated::commandArgs(verilated_argc, verilated_argv);
    Verilated::traceEverOn(true);
    top = new VTOP(Vname);

#ifdef USE_TRACE
    VerilatedVcdC *tfp = new VerilatedVcdC();
    top->trace(tfp, 0);
    tfp->open("wave.vcd");
#endif

    {
        top->clk = 0;
        top->rst = 1;
        top->eval();
#ifdef USE_TRACE
        tfp->dump(main_time++);
#endif
        top->clk = 1;
        top->rst = 1;
        top->eval();
#ifdef USE_TRACE
        tfp->dump(main_time++);
#endif
        top->rst = 0;
    }

    // Simulate until $finish
    while ((main_time < max_simTime) && !Verilated::gotFinish())
    {
        // Evaluate model
        top->clk = !top->clk;
        top->eval();
#ifdef USE_TRACE
        tfp->dump(main_time);
#endif
        ++main_time;
    }

    top->final();

#ifdef USE_TRACE
    tfp->close();
#endif

    delete top;
    return 0;
}