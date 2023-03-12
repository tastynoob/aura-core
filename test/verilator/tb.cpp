#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb.h"

const bool dump_wave = true;
const uint64_t max_simTime = 1000;

uint64_t main_time = 0;
int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(dump_wave);
    VerilatedVcdC *tfp;
    if (dump_wave)
    {
        tfp = new VerilatedVcdC();
    }

    Vtb *top = new Vtb("tb");
    if (dump_wave)
    {
        top->trace(tfp, 0);
        tfp->open("wave.vcd");
    }

    {
        top->clk = 0;
        top->rst = 1;
        top->eval();
        if (dump_wave)
        {
            tfp->dump(main_time++);
        }
        top->clk = 1;
        top->rst = 1;
        top->eval();
        if (dump_wave)
        {
            tfp->dump(main_time++);
        }
        top->rst = 0;
    }

    // Simulate until $finish
    while ((main_time < max_simTime) && !Verilated::gotFinish())
    {
        // Evaluate model
        top->clk = !top->clk;
        top->eval();
        if (dump_wave)
        {
            tfp->dump(main_time);
        }
        ++main_time;
    }

    top->final();
    if (dump_wave)
    {
        tfp->close();
    }

    delete top;
    return 0;
}