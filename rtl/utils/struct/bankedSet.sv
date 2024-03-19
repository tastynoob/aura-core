`include "base.svh"




// {set index, offset}
module bankedSet #(
    parameter int  BANKS = 4,
    parameter int  SETS  = 64,
    parameter int  WAYS  = 4,
    parameter type dtype = logic
) (
    input wire clk,
    input wire rst,

    input wire [`WDEF(BANKS)] i_write,
    input wire [`WDEF(BANKS)] i_read,
    input wire [`WDEF(WAYS)] i_way_sel[BANKS],
    input wire [`WDEF($clog2(SETS))] i_addr[BANKS],
    input wire [`WDEF(DATASIZE)] i_data[BANKS],
    output wire [`WDEF(DATASIZE)] o_data[BANKS]
);
    genvar i;

    generate
        for (i = 0; i < BANKS; i = i + 1) begin
            dtype read_datas[WAYS];
            dtype write_datas[WAYS];
            genvar j;
            for (j = 0; j < WAYS; j = j + 1) begin
                assign write_datas[j] = i_data[i];
            end

            sramSet #(
                .SETS (SETS / BANKS),
                .WAYS (WAYS),
                .dtype(dtype)
            ) u_sramSet (
                .clk           (clk),
                .rst           (rst),
                .i_addr        (i_addr[i]),
                .i_read_en     (i_read[i]),
                .i_write_en_vec(i_write ? i_way_sel[i] : 0),
                .o_read_data   (read_datas),
                .i_write_data  (write_datas)
            );
            dtype read_temp;
            always_comb begin
                int ca;
                for (ca = 0; ca < WAYS; ca = ca + 1) begin
                    if (i_way_sel[i][ca]) begin
                        read_temp = read_datas[ca];
                    end
                end
            end
            `ASSET(func::count_one(i_way_sel) < 2);
            assign o_data[i] = read_temp;
        end
    endgenerate

endmodule

