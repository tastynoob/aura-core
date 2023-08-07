#include <verilated.h>
#include <verilated_vcd_c.h>
#include <string>
#include "Vtb.h"
#include "cmdline.hpp"


uint64_t max_simTime = 1000;
uint64_t main_time = 0;
VTOP *top;

int main(int argc, char **argv)
{
    cmdline::parser parser;
    parser.add<std::string>("exec-file",'f',"the riscv executable binary file path",false);
    parser.add<std::string>("end",'e',"end simulation by specific conditions\n"
    "       e.g\n"
    "           -e i100 t25\n"
    "       end simulation at 100th instruction or 25th tick"
    ,false);
    parser.add<uint32_t>("seed",'s',"the seed of x-assign random init",false);
#ifdef USE_TRACE
    parser.add<std::string>("trace",0,"enable trace by specific conditions\n"
    "       e.g\n"
    "           --trace i100 t25\n"
    "       enable trace starting at 100th instruction or 25th tick"
    ,false);
#endif
    parser.parse_check(argc,argv);


    Verilated::commandArgs(argc, argv);
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