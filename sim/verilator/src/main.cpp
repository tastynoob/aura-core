#include <verilated.h>
#include <verilated_vcd_c.h>
#include <string>
#include <random>
#include Vheader
#include "cmdline.hpp"
#include "statistics.hpp"
#include "flags.hpp"

uint64_t max_simTime = 99999999999lu;
uint64_t main_time = 0;
VTOP *top;
VerilatedVcdC *tfp;
char buffer[100];

uint64_t curTick() { return main_time; }

extern void diff_init(const char* ref_path);
extern void init_workload(std::string path);


void tick_init_top() {
    top->clk = 0;
    top->rst = 1;
    top->eval();
#ifdef USE_TRACE
    tfp->dump(main_time);
#endif

    main_time++;
    top->clk = 1;
    top->rst = 1;
    top->eval();
#ifdef USE_TRACE
    tfp->dump(main_time);
#endif

    main_time++;
    top->rst = 0;
}

void tick_step() {
    top->clk = !top->clk;
    top->eval();
#ifdef USE_TRACE
    tfp->dump(main_time);
#endif
    ++main_time;
}


int main(int argc, char **argv)
{
    for (int i = 0; i < argc; i++)
    {
        std::cout << argv[i] << " ";
    }
    std::cout << std::endl;
    cmdline::parser parser;
    parser.add<std::string>("exec-file", 'f', "the riscv executable binary file path", true);
    parser.add<std::string>("end", 'e', "end simulation by specific conditions\n"
                                        "       e.g\n"
                                        "           -e i100t25\n"
                                        "       end simulation at 100th instruction or 25th tick",
                            false);
    parser.add<uint32_t>("seed", 's', "the seed of x-assign random init", false);
    parser.add<std::string>("diff-so", 'd', "the so of difftest ref", false);
    parser.add<std::string>("debug-flags", 0, "the debug flags", false);
#ifdef USE_TRACE
    parser.add<std::string>("trace", 0, "enable trace by specific conditions\n"
                                        "       e.g\n"
                                        "           --trace i100t25\n"
                                        "       enable trace starting at 100th instruction or 25th tick",
                            false);
#endif

    parser.parse_check(argc, argv);

    if (parser.exist("debug-flags")) {
        debugChecker.enableFlags(parser.get<std::string>("debug-flags"));
    }
    if (parser.exist("exec-file"))
    {
        std::string workload_path = parser.get<std::string>("exec-file");
        init_workload(workload_path);
    }
    if (parser.exist("diff-so"))
    {
        diff_init(parser.get<std::string>("diff-so").c_str());
    }

    int verilated_seed; 
    if (parser.exist("seed"))
    {
        verilated_seed = parser.get<uint32_t>("seed");
    }
    else {
        std::random_device rd;
        verilated_seed = rd() % 10000;
    }

    std::cout << "verilated random seed: " << verilated_seed << std::endl;

    if (parser.exist("end"))
    {
        std::string cmd = parser.get<std::string>("end");
        uint64_t i, t;
        int count = sscanf(cmd.c_str(), "t%lu", &t);
        if (count)
        {
            max_simTime = t;
        }
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
    Verilated::addExitCb([](void *)
                         { std::cout << "Exiting tick at: " << main_time << std::endl; },
                         nullptr);
    top = new VTOP(Vname);

#ifdef USE_TRACE
    tfp = new VerilatedVcdC();
    top->trace(tfp, 0);
    tfp->open("wave.vcd");
    printf("Start trace at: %d\n", 0);
#endif

    std::cout << "**** MAX EMULATION TICK: " << max_simTime << " ****\n";
    std::cout << "**** REAL EMULATION ****\n";

    tick_init_top();
    
    // Simulate until $finish
    while ((main_time < max_simTime) && !force_exit())
    {
        // Evaluate model
        tick_step();
        debugChecker.printAll();
    }
    top->final();


#ifdef USE_TRACE
    tfp->close();
#endif

    delete top;

    int ret_code = 0;
    std::cout<<std::endl;
    if (force_exit() == 1) {
        std::cout << "**** RUN FAILED! ****\n";
        ret_code = 1;
    }
    else {
        std::cout << "**** [" << main_time << "] END EMULATION, DUMP STATS ****\n";
        if (force_exit() == 2) {
            std::cout << "[active exit] Exit due to call quit\n";
        }
        dumpStats();
    }

    return ret_code;
}