


module bpu_test (
    input wire clk,
    input rst
);


reg close;
int count;
reg update_vld;
wire update_finished;
always_ff @( posedge clk ) begin
    if (rst) begin
        count <= 0;
        update_vld <= 0;
        close <= 0;
    end
    else begin
        count <= count + 1;
        if (update_finished) begin
            update_vld <= 0;
        end

        if (count >= 10 && (!close)) begin
            update_vld <= 1;
            close <= 1;
        end
    end
end

BPupdateInfo_t ftb_update = '{
    startAddr : `INIT_PC + 20*64,
    ftb_update : '{
        carry : 0,
        fallthruAddr : 16,
        tarStat : tarStat_t::FIT,
        targetAddr : 0,
        branch_type : BranchType::isCond,
        counter : 2
    }
};


BPU u_BPU(
    .clk               ( clk               ),
    .rst               ( rst               ),

    .i_squash_vld      ( 0      ),
    .i_squashInfo      (      ),

    .i_update_vld      ( update_vld     ),
    .o_update_finished ( update_finished ),
    .i_BPupdateInfo    ( ftb_update   ),

    .o_pred_vld        (        ),
    .o_pred_ftqInfo    (    )
);




endmodule

