`include "base.svh"





module array2vec #(
    parameter int  ARRAYLENGTH = 1,
    parameter type dtype       = logic
) (
    input dtype i_array[ARRAYLENGTH],
    output dtype [ARRAYLENGTH:0] o_vec
);
    genvar i;

    generate
        for (i = 0; i < ARRAYLENGTH; i = i + 1) begin
            assign o_vec[i] = i_array[i];
        end
    endgenerate
endmodule
