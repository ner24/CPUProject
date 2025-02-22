//alu combinational logic only
module alu_comb #(
    parameter DATA_WIDTH = 16
) (
    input  wire  [DATA_WIDTH-1:0] a,
    input  wire  [DATA_WIDTH-1:0] b,
    output wire  [DATA_WIDTH-1:0] out,
    input  wire                   out_en,
    output wire                   cout, //17th bit. Carry out for addition
    input  wire             [7:0] ctrl,
    input  wire                   cin
);
    //twos complement inverter
    wire[DATA_WIDTH - 1:0] invA;
    alu_inverter #(
        .DATA_WIDTH(DATA_WIDTH)
    ) inv0 (
        .a(a),
        .twos_en(ctrl[7]),
        .all_en(ctrl[6]),
        .invA(invA)
    );

    //enable b input (for NOT functionality)
    wire[DATA_WIDTH - 1:0] b_with_en;
    generate for (genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
        assign b_with_en[i] = b[i] & ~ctrl[6];
    end endgenerate

    //modified adder
    //bottom half
    wire[DATA_WIDTH-1:0] cla_lh_oX;
    wire[DATA_WIDTH-1:0] cla_lh_cgen_out;
    wire[DATA_WIDTH-1:0] cla_lh_cgen;
    alu_add_cla_lh #(
        .DATA_WIDTH(DATA_WIDTH)
    ) cla_lh_0 (
        .a(invA),
        .b(b_with_en),
        .oX(cla_lh_oX),
        .cgen(cla_lh_cgen_out),
        .cgen_en(ctrl[5])
    );

    //OR gate extra wire
    generate for (genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
        assign cla_lh_cgen[i] = (cla_lh_oX[i] & ctrl[4]) | cla_lh_cgen_out[i];
    end endgenerate
    
    //top half
    wire[DATA_WIDTH - 1:0] cla_s;
    wire cout_internal;
    alu_add_cla_uh #(
        .DATA_WIDTH(DATA_WIDTH)
    ) cla_uh_0 (
        .oX(cla_lh_oX),
        .cgen(cla_lh_cgen),
        .cin(cin),
        .cout(cout_internal),
        .s(cla_s),
        .carry_en(ctrl[3])
    );

    //output before xor invert array
    wire[DATA_WIDTH - 1:0] out_nI;
    generate for(genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
        assign out_nI[i] = (cla_s[i] & ctrl[2]) | (cla_lh_cgen[i] & ctrl[1]);
    end endgenerate

    //xor invert array
    wire [DATA_WIDTH-1:0] out_internal;
    generate for(genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
        assign out_internal[i] = out_nI[i] ^ ctrl[0];
    end endgenerate

    assign out = out_en ? out_internal : 'b0;
    assign cout = out_en ? cout_internal : 'b0;

endmodule: alu_comb
