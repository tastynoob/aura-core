`include "core_define.svh"




//how to process multi (mv x2,x1)?
//TODO: check for logic correctness
//TODO: how about MEMartix implement?
module renametable(
    input wire clk,
    input wire rst,

    output wire o_can_rename,

    //need to rename's rs idx
    input ilrIdx_t i_ilrs1_idx[`RENAME_WIDTH],
    input ilrIdx_t i_ilrs2_idx[`RENAME_WIDTH],
    //renamed physic rs idx
    output iprIdx_t o_iprs1_idx[`RENAME_WIDTH],
    output iprIdx_t o_iprs2_idx[`RENAME_WIDTH],
    //need to rename's rd idx
    input wire[`WDEF(`RENAME_WIDTH)] i_ilrd_vld,
    input wire[`WDEF(`RENAME_WIDTH)] i_ilrd_ismv,
    input ilrIdx_t i_ilrd_idx[`RENAME_WIDTH],
    output iprIdx_t o_iprd_idx[`RENAME_WIDTH],

    //dealloc phyIdx
    input wire[`WDEF(`COMMIT_WIDTH)] i_dealloc_req,
    input iprIdx_t i_dealloc_prIdx[`COMMIT_WIDTH]
);
    genvar i;
    //x0 can not ne renamed
    iprIdx_t rat[1:32];
    //read directly from rat
    iprIdx_t renamed0_iprs1_idx[`RENAME_WIDTH],renamed0_iprs2_idx[`RENAME_WIDTH];
    //reselect ftom rat and freelist
    iprIdx_t renamed1_iprs1_idx[`RENAME_WIDTH],renamed1_iprs2_idx[`RENAME_WIDTH];
    //carried by inst in rob
    iprIdx_t prev_renamed_iprd_idx[`RENAME_WIDTH];

    iprIdx_t renamed_iprd_idx[`RENAME_WIDTH];

    iprIdx_t freelist_alloc_iprd_idx[`RENAME_WIDTH];

    generate
        for(i=0;i<`RENAME_WIDTH;i=i+1) begin:gen_for
            assign renamed0_iprs1_idx[i] = rat[i_ilrs1_idx[i]];
            assign renamed0_iprs2_idx[i] = rat[i_ilrs2_idx[i]];
            assign prev_renamed_iprd_idx[i] = rat[i_ilrd_idx[i]];
        end
    endgenerate

    always_ff @( posedge clk ) begin : blockName
        integer j;
        if (rst==true) begin
            for (j=1;j<32;j=j+1) begin
                rat[i] <= 0;
            end
        end else begin
            for(j=0;j<`RENAME_WIDTH;j=j+1) begin
                if (i_ilrd_vld[i]) begin//uodate the rat maping
                    rat[i_ilrd_idx[i]] <= renamed_iprd_idx[i];
                end
            end
        end
    end

    // if ismv and prev_iprd == renamed_iprs1 , ignore refcount inc
    wire[`WDEF(`RENAME_WIDTH)] mv_iprd_equal_iprs1;
    generate
        for(i=0;i<`RENAME_WIDTH;i=i+1) begin: gen_for
            assign mv_iprd_equal_iprs1[i] =
            i_ilrd_ismv[i] & (prev_renamed_iprd_idx[i] == renamed1_iprs1_idx[i]);
        end
    endgenerate

    wire[`WDEF(`RENAME_WIDTH)] real_alloc_req;
    assign real_alloc_req = i_ilrd_vld & (~i_ilrd_ismv) && (~mv_iprd_equal_iprs1);

    wire[`WDEF(`RENAME_WIDTH)] real_dealloc_req;
    iprIdx_t real_dealloc_prIdx[`RENAME_WIDTH];

    freelist u_freelist(
        .clk             ( clk             ),
        .rst             ( rst             ),

        .o_can_alloc     ( o_can_rename     ),
        .i_alloc_req     ( real_alloc_req     ),
        //output direct by real_alloc_req
        .o_alloc_prIdx   ( freelist_alloc_iprd_idx   ),

        .i_dealloc_req   ( real_dealloc_req   ),
        .i_dealloc_prIdx ( real_dealloc_prIdx )
    );


    //rename the dst and src regIdx
    always_comb begin
        integer j,k;
        for(j=0;j<`RENAME_WIDTH;j=j+1) begin
            if (i_ilrd_ismv[j]) begin
                renamed_iprd_idx[j] = renamed1_iprs1_idx[j];
            end else begin
                renamed_iprd_idx[j] = freelist_alloc_iprd_idx[j];
            end

            renamed1_iprs1_idx[j] = renamed0_iprs1_idx[j];
            renamed1_iprs2_idx[j] = renamed0_iprs2_idx[j];
            for(k=0;k<j;k=k+1) begin
                if ((i_ilrs1_idx[j] == i_ilrd_idx[k]) && i_ilrd_vld[k]) begin
                    renamed1_iprs1_idx[j] = renamed_iprd_idx[k];
                end
                if ((i_ilrs2_idx[j] == i_ilrd_idx[k]) && i_ilrd_vld[k]) begin
                    renamed1_iprs2_idx[j] = renamed_iprd_idx[k];
                end
            end
        end
    end





    //only for rvI regfile
    refcount u_refcount(
        .clk                  ( clk                  ),
        .rst                  ( rst                  ),

        .i_alloc_req          ( real_alloc_req          ),
        .i_alloc_prIdx        ( renamed_iprd_idx        ),

        .i_dealloc_req        ( i_dealloc_req        ),
        .i_dealloc_prIdx      ( i_dealloc_prIdx      ),

        .o_real_dealloc_req   ( real_dealloc_req   ),
        .o_real_dealloc_prIdx ( real_dealloc_prIdx )
    );








endmodule
