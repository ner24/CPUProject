//alu combinational logic only
module alpu_comb #(
    parameter REG_WIDTH = 16
) (
    input  wire   [REG_WIDTH-1:0] a,
    input  wire   [REG_WIDTH-1:0] b,
    output wire   [REG_WIDTH-1:0] out,
    output wire                   cout, //17th bit. Carry out for addition
    input  wire             [7:0] ctrl,
    input  wire                   cin
);
    //twos complement inverter
    wire[REG_WIDTH - 1:0] invA;
    alpu_inverter #(
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
    alpu_add_cla_lh #(
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
    alpu_add_cla_uh #(
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

endmodule: alpu_comb
