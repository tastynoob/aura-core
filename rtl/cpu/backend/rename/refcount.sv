`include "rename_define.svh"

//li x1,1
//mv x2,x1
//mv x2,x1

//unordered in out
module refcount(
    input wire clk,
    input wire rst,
    //alloc: refcount inc
    input wire[`WDEF(`RENAME_WIDTH)] i_alloc_req,
    input iprIdx_t i_alloc_prIdx[`RENAME_WIDTH],
    //dealloc: refcount dec
    input wire[`WDEF(`COMMIT_WIDTH)] i_dealloc_req,
    input iprIdx_t i_dealloc_prIdx[`COMMIT_WIDTH],
    //the real physic reg need to dealloc
    output wire[`WDEF(`COMMIT_WIDTH)] o_real_dealloc_req,
    output iprIdx_t o_real_dealloc_prIdx[`COMMIT_WIDTH]
);
    //the logic x0 is no need to process
    reg[`SDEF(32)] refcounts[1:`IPHYREG_NUM];
    wire[`SDEF(32)] refcounts_next[1:`IPHYREG_NUM];
    wire[`IPHYREG_NUM:1] refcounts_inc_mask[`RENAME_WIDTH]/* verilator split_var */;
    wire[`IPHYREG_NUM:1] refcounts_dec_mask[`COMMIT_WIDTH]/* verilator split_var */;
    wire[`IPHYREG_NUM:1] refcounts_inc,refcounts_dec;
    genvar i;
    generate
        wire[`WDEF(`IPHYREG_NUM)] OneHot_inc[`RENAME_WIDTH];
        for(i=0;i<`RENAME_WIDTH;i=i+1) begin : gen_for
            assign OneHot_inc[i] = `IPHYREG_NUM'd1<<i_alloc_prIdx[i];
            if (i==0)begin:gen_if
                assign refcounts_inc_mask[i] =
                i_alloc_req[i] ? OneHot_inc[i][`IPHYREG_NUM-1:1] : 0;
            end else begin : gen_elif
                assign refcounts_inc_mask[i] =
                (i_alloc_req[i] ? OneHot_inc[i][`IPHYREG_NUM-1:1] : 0) | refcounts_inc_mask[i-1];
            end
        end
        assign refcounts_inc = refcounts_inc_mask[`RENAME_WIDTH-1];
    endgenerate

    generate
        wire[`WDEF(`IPHYREG_NUM)] OneHot_dec[`COMMIT_WIDTH];
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin : gen_for
            assign OneHot_dec[i] = `IPHYREG_NUM'd1<<i_dealloc_prIdx[i];
            if (i==0)begin:gen_if
                assign refcounts_dec_mask[i] =
                i_dealloc_req[i] ? OneHot_dec[i][`IPHYREG_NUM-1:1] : 0;
            end else begin : gen_elif
                assign refcounts_dec_mask[i] =
                (i_dealloc_req[i] ? OneHot_dec[i][`IPHYREG_NUM-1:1] : 0) | refcounts_dec_mask[i-1];
            end
        end
        assign refcounts_dec = refcounts_dec_mask[`COMMIT_WIDTH-1];
    endgenerate

    generate
        for(i=0;i<`IPHYREG_NUM;i=i+1) begin : gen_for
            if(i==0)begin:gen_if
            end else begin:gen_elif
                always_ff @( posedge clk ) begin :gen_0
                    if(rst == true)begin
                        refcounts[i] <= 0;
                    end else begin
                        refcounts[i] <= refcounts_next[i];
                    end
                end
                assign refcounts_next[i] = refcounts[i] - refcounts_dec[i] + refcounts_inc[i];
            end
        end
    endgenerate

    generate
        for(i=0;i<`COMMIT_WIDTH;i=i+1)begin:gen_for
            assign o_real_dealloc_req[i] =
            refcounts_next[i_dealloc_prIdx[i]] == 0 ? true : false;
            assign o_real_dealloc_prIdx[i] = i_dealloc_prIdx[i];
        end
    endgenerate

endmodule

