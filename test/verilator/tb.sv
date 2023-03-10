

module tb ();

    reg [4:0] test0, test1;

    bool c;
    sys_ctrl sys;
    assign sys.clk = 0;
    assign sys.rst = 0;
    fifo u_fifo (
        .if_sys(sys)
    );

endmodule


