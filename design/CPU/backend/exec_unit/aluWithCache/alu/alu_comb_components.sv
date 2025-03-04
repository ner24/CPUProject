module alu_inverter #(
    parameter DATA_WIDTH = 4
)(
    input logic[DATA_WIDTH - 1:0] a,
    input logic twos_en,
    input logic all_en,
    output wire[DATA_WIDTH - 1:0] invA
);

    wire[DATA_WIDTH-1:0] invRail;
    assign invRail[0] = all_en;

    generate
        for(genvar i = 1; i < DATA_WIDTH; i = i + 1) begin
            assign invRail[i] = invRail[i - 1] | (twos_en & a[i - 1]);
        end
        for(genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
            assign invA[i] = invRail[i] ^ a[i];
        end
    endgenerate

endmodule

module alu_add_cla_lh #( //lower half of carry look ahead adder (i.e. just the and and xor)
    parameter DATA_WIDTH = 4
)(
    input  wire[DATA_WIDTH-1:0] a,
    input  wire[DATA_WIDTH-1:0] b,
    output wire[DATA_WIDTH-1:0] oX,
    output wire[DATA_WIDTH-1:0] cgen,
    input  wire cgen_en
);
    generate
        for(genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
            assign oX[i] = a[i] ^ b[i];
            assign cgen[i] = a[i] & b[i] & cgen_en;
        end
    endgenerate

endmodule

module alu_add_cla_uh #( //upper half of carry look ahead adder (i.e. carry chain and sum xor)
    parameter DATA_WIDTH = 4
) (
    input wire[DATA_WIDTH - 1:0] oX,
    input wire[DATA_WIDTH - 1:0] cgen,
    input wire cin,
    output wire cout,
    output wire[DATA_WIDTH - 1:0] s,
    input wire carry_en
);
    wire[DATA_WIDTH:0] carry_chain;
    
    assign carry_chain[0] = cin;
    assign cout = carry_chain[DATA_WIDTH];
    generate
        for(genvar i = 1; i <= DATA_WIDTH; i = i + 1) begin
            assign carry_chain[i] = (carry_en & carry_chain[i - 1] & oX[i - 1]) | cgen[i - 1];
        end
        for(genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
            assign s[i] = carry_chain[i] ^ oX[i];
        end
    endgenerate
endmodule
