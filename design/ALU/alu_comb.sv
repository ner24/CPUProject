//alu combinational logic only
module alu_comb #(
    parameter REG_WIDTH = 16
) (
    input  logic[REG_WIDTH-1:0]   a,
    input  logic[REG_WIDTH-1:0]   b,
    input  logic[REG_WIDTH-1:0]   out,
    output logic                    cout, //17th bit. Carry out for addition
    input  logic[7:0]               ctrl,
    input  wire                     cin
);
    //connections. Doing this way for more flexibility with connecting to rest of processor

    //twos complement inverter
    wire[REG_WIDTH - 1:0] invA;
    alu_inverter #(
        .REG_WIDTH(REG_WIDTH)
    ) inv0 (
        .a(a),
        .twos_en(ctrl[7]),
        .all_en(ctrl[6]),
        .invA(invA)
    );

    //enable b input (for NOT functionality)
    wire[REG_WIDTH - 1:0] b_with_en;
    generate for (genvar i = 0; i < REG_WIDTH; i = i + 1) begin
            assign b_with_en[i] = b[i] & ~ctrl[6];
    end endgenerate

    //modified adder
    //bottom half
    wire[REG_WIDTH-1:0] cla_lh_oX;
    wire[REG_WIDTH-1:0] cla_lh_cgen_out;
    wire[REG_WIDTH-1:0] cla_lh_cgen;
    alu_add_cla_lh #(
        .REG_WIDTH(REG_WIDTH)
    ) cla_lh_0 (
        .a(invA),
        .b(b_with_en),
        .oX(cla_lh_oX),
        .cgen(cla_lh_cgen_out),
        .cgen_en(ctrl[5])
    );

    //OR gate extra wire
    generate for (genvar i = 0; i < REG_WIDTH; i = i + 1) begin
        assign cla_lh_cgen[i] = (cla_lh_oX[i] & ctrl[4]) | cla_lh_cgen_out[i];
    end endgenerate
    
    //top half
    wire[REG_WIDTH - 1:0] cla_s;
    alu_add_cla_uh #(
        .REG_WIDTH(REG_WIDTH)
    ) cla_uh_0 (
        .oX(cla_lh_oX),
        .cgen(cla_lh_cgen),
        .cin(cin),
        .cout(cout),
        .s(cla_s),
        .carry_en(ctrl[3])
    );

    //output before xor invert array
    wire[REG_WIDTH - 1:0] out_nI;
    generate for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin
        assign out_nI[i] = (cla_s[i] & ctrl[2]) | (cla_lh_cgen[i] & ctrl[1]);
    end endgenerate

    //xor invert array
    generate for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin
        assign out[i] = out_nI[i] ^ ctrl[0];
    end endgenerate

endmodule: alu_comb

module alu_inverter #(
    parameter REG_WIDTH
)(
    input logic[REG_WIDTH - 1:0] a,
    input logic twos_en,
    input logic all_en,
    output wire[REG_WIDTH - 1:0] invA
);

    wire[REG_WIDTH-1:0] invRail;
    assign invRail[0] = all_en;

    generate
        for(genvar i = 1; i < REG_WIDTH; i = i + 1) begin
            assign invRail[i] = invRail[i - 1] | (twos_en & a[i - 1]);
        end
        for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin
            assign invA[i] = invRail[i] ^ a[i];
        end
    endgenerate

endmodule

module alu_add_cla_lh #( //lower half of carry look ahead adder (i.e. just the and and xor)
    parameter REG_WIDTH
)(
    input  wire[REG_WIDTH-1:0] a,
    input  wire[REG_WIDTH-1:0] b,
    output wire[REG_WIDTH-1:0] oX,
    output wire[REG_WIDTH-1:0] cgen,
    input  wire cgen_en
);
    generate
        for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin
            assign oX[i] = a[i] ^ b[i];
            assign cgen[i] = a[i] & b[i] & cgen_en;
        end
    endgenerate

endmodule

module alu_add_cla_uh #( //upper half of carry look ahead adder (i.e. carry chain and sum xor)
    parameter REG_WIDTH
) (
    input wire[REG_WIDTH - 1:0] oX,
    input wire[REG_WIDTH - 1:0] cgen,
    input wire cin,
    output wire cout,
    output wire[REG_WIDTH - 1:0] s,
    input wire carry_en
);
    wire[REG_WIDTH:0] carry_chain;
    
    assign carry_chain[0] = cin;
    assign cout = carry_chain[REG_WIDTH];
    generate
        for(genvar i = 1; i <= REG_WIDTH; i = i + 1) begin
            assign carry_chain[i] = (carry_en & carry_chain[i - 1] & oX[i - 1]) | cgen[i - 1];
        end
        for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin
            assign s[i] = carry_chain[i] ^ oX[i];
        end
    endgenerate
endmodule
