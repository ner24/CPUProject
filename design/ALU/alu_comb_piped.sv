//alu combinational logic only
module alu_comb_piped #(
  parameter REG_WIDTH = 16
) (
  input  wire                  clk,
  input  wire                  reset_n,

  input  wire  [REG_WIDTH-1:0] a,
  input  wire  [REG_WIDTH-1:0] b,
  output wire  [REG_WIDTH-1:0] out,
  output wire                  cout, //17th bit. Carry out for addition
  input  wire            [7:0] ctrl,
  input  wire                  cin,

  input  wire                  pipe_active
);

  // ----------------------------------------
  // Stage 0 (S0)
  // ----------------------------------------
  logic[REG_WIDTH-1:0] invA_s0;
  logic[REG_WIDTH-1:0] b_with_en_s0;

  //twos complement inverter
  wire[REG_WIDTH-1:0] invA;
  alu_inverter #(
    .REG_WIDTH(REG_WIDTH)
  ) inv0 (
    .a(a),
    .twos_en(ctrl[7]),
    .all_en(ctrl[6]),
    .invA(invA)
  );

  //enable b input (for NOT functionality)
  wire[REG_WIDTH-1:0] b_with_en;
  generate for (genvar i = 0; i < REG_WIDTH; i = i + 1) begin
    assign b_with_en[i] = b[i] & ~ctrl[6];
  end endgenerate

  always_ff @(posedge clk) begin : ff_s0
    if(~reset_n) begin
      invA_s0      <= '0;
      b_with_en_s0 <= '0;
    end else if (pipe_active) begin
      invA_s0      <= invA;
      b_with_en_s0 <= b_with_en;
    end
  end

  // ----------------------------------------
  // Stage 1 (S1)
  // ----------------------------------------
  logic [REG_WIDTH-1:0] cla_lh_oX_s1;
  logic [REG_WIDTH-1:0] cla_lh_cgen_out_s1;
  logic [REG_WIDTH-1:0] cla_lh_cgen_s1;

  //flop slice of ctrl which is relevant to s1
  logic [5:4] ctrl_s1;

  //modified adder
  //bottom half
  wire  [REG_WIDTH-1:0] cla_lh_oX;
  wire  [REG_WIDTH-1:0] cla_lh_cgen_out;
  wire  [REG_WIDTH-1:0] cla_lh_cgen;
  alu_add_cla_lh #(
    .REG_WIDTH(REG_WIDTH)
  ) cla_lh_0 (
    .a(invA_s0),
    .b(b_with_en_s0),
    .oX(cla_lh_oX),
    .cgen(cla_lh_cgen_out),
    .cgen_en(ctrl_s1[5])
  );

  //OR gate extra wire
  generate for (genvar i = 0; i < REG_WIDTH; i = i + 1) begin
      assign cla_lh_cgen[i] = (cla_lh_oX[i] & ctrl_s1[4]) | cla_lh_cgen_out[i];
  end endgenerate

  always_ff @(posedge clk) begin : ff_s1
    if(~reset_n) begin
      cla_lh_oX_s1       <= '0;
      cla_lh_cgen_out_s1 <= '0;
      cla_lh_cgen_s1     <= '0;
      ctrl_s1            <= '0;
    end else if (pipe_active) begin
      cla_lh_oX_s1       <= cla_lh_oX;
      cla_lh_cgen_out_s1 <= cla_lh_cgen_out;
      cla_lh_cgen_s1     <= cla_lh_cgen;
      ctrl_s1            <= ctrl[5:4];
    end
  end

  // ----------------------------------------
  // Stage 2 (S2)
  // ----------------------------------------
  logic [REG_WIDTH-1:0] out_s2;
  logic                 cout_s2;

  //flop ctrl slice relevant for s2
  logic [3:0]           ctrl_s2;

  //top half
  wire  [REG_WIDTH-1:0] cla_s;
  wire                  cout_internal;
  alu_add_cla_uh #(
    .REG_WIDTH(REG_WIDTH)
  ) cla_uh_0 (
    .oX(cla_lh_oX_s1),
    .cgen(cla_lh_cgen_s1),
    .cin(cin),
    .cout(cout_internal),
    .s(cla_s),
    .carry_en(ctrl[3])
  );

  //output before xor invert array
  wire  [REG_WIDTH-1:0] out_nI;
  wire  [REG_WIDTH-1:0] out_internal;
  generate for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin
    assign out_nI[i] = (cla_s[i] & ctrl_s2[2]) | (cla_lh_cgen_s1[i] & ctrl_s2[1]);
    assign out_internal[i] = out_nI[i] ^ ctrl_s2[0];
  end endgenerate

  always_ff @(posedge clk) begin : ff_s2
    if(~reset_n) begin
      out_s2       <= '0;
      cout_s2      <= '0;
      ctrl_s2      <= '0;
    end else if (pipe_active) begin
      out_s2       <= out_internal;
      cout_s2      <= cout_internal;
      ctrl_s2      <= ctrl[3:0];
    end
  end

  // ----------------------------------------
  // Outputs
  // ----------------------------------------
  assign out  = out_s2;
  assign cout = cout_s2;

endmodule
