//alu combinational logic only
module alu_comb_piped #(
  parameter DATA_WIDTH = 16
) (
  input  wire                  clk,
  input  wire                  reset_n,

  input  wire  [DATA_WIDTH-1:0] a,
  input  wire  [DATA_WIDTH-1:0] b,
  output wire  [DATA_WIDTH-1:0] out,
  input  wire                  out_en,
  output wire                  cout, //17th bit. Carry out for addition
  input  wire            [7:0] ctrl,
  input  wire                  cin,

  input  wire                  pipe_active
);

  // ----------------------------------------
  // Stage 0 (S0)
  // ----------------------------------------
  logic[DATA_WIDTH-1:0] invA_s0;
  logic[DATA_WIDTH-1:0] b_with_en_s0;
  logic                cin_s0;

  logic          [5:0] ctrl_s0;

  //twos complement inverter
  wire[DATA_WIDTH-1:0] invA;
  alu_inverter #(
    .DATA_WIDTH(DATA_WIDTH)
  ) inv0 (
    .a(a),
    .twos_en(ctrl[7]),
    .all_en(ctrl[6]),
    .invA(invA)
  );

  //enable b input (for NOT functionality)
  wire[DATA_WIDTH-1:0] b_with_en;
  generate for (genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
    assign b_with_en[i] = b[i] & ~ctrl[6];
  end endgenerate

  always_ff @(posedge clk /*or negedge reset_n*/) begin : ff_s0
    if(~reset_n) begin
      invA_s0      <= '0;
      b_with_en_s0 <= '0;
      cin_s0       <= '0;
      ctrl_s0      <= '0;
    end else if (pipe_active) begin
      invA_s0      <= invA;
      b_with_en_s0 <= b_with_en;
      cin_s0       <= cin;
      ctrl_s0      <= ctrl[5:0];
    end
  end

  // ----------------------------------------
  // Stage 1 (S1)
  // ----------------------------------------
  logic [DATA_WIDTH-1:0] cla_lh_oX_s1;
  //logic [DATA_WIDTH-1:0] cla_lh_cgen_out_s1;
  logic [DATA_WIDTH-1:0] cla_lh_cgen_s1;
  logic                 cin_s1;

  //flop slice of ctrl which is relevant to s1
  logic [3:0] ctrl_s1;

  //modified adder
  //bottom half
  wire  [DATA_WIDTH-1:0] cla_lh_oX;
  wire  [DATA_WIDTH-1:0] cla_lh_cgen_out;
  wire  [DATA_WIDTH-1:0] cla_lh_cgen;
  alu_add_cla_lh #(
    .DATA_WIDTH(DATA_WIDTH)
  ) cla_lh_0 (
    .a(invA_s0),
    .b(b_with_en_s0),
    .oX(cla_lh_oX),
    .cgen(cla_lh_cgen_out),
    .cgen_en(ctrl_s0[5])
  );

  //OR gate extra wire
  generate for (genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
    assign cla_lh_cgen[i] = (cla_lh_oX[i] & ctrl_s0[4]) | cla_lh_cgen_out[i];
  end endgenerate

  always_ff @(posedge clk /*or negedge reset_n*/) begin : ff_s1
    if(~reset_n) begin
      cla_lh_oX_s1       <= '0;
      cla_lh_cgen_s1     <= '0;
      ctrl_s1            <= '0;
      cin_s1             <= '0;
    end else if (pipe_active) begin
      cla_lh_oX_s1       <= cla_lh_oX;
      cla_lh_cgen_s1     <= cla_lh_cgen;
      ctrl_s1            <= ctrl_s0[3:0];
      cin_s1             <= cin_s0;
    end
  end

  // ----------------------------------------
  // Stage 2 (S2)
  // ----------------------------------------
  logic [DATA_WIDTH-1:0] out_s2;
  logic                 cout_s2;

  //flop ctrl slice relevant for s2
  //logic [3:0]           ctrl_s2;

  //top half
  wire  [DATA_WIDTH-1:0] cla_s;
  wire                  cout_internal;
  alu_add_cla_uh #(
    .DATA_WIDTH(DATA_WIDTH)
  ) cla_uh_0 (
    .oX(cla_lh_oX_s1),
    .cgen(cla_lh_cgen_s1),
    .cin(cin_s1),
    .cout(cout_internal),
    .s(cla_s),
    .carry_en(ctrl_s1[3])
  );

  //output before xor invert array
  wire  [DATA_WIDTH-1:0] out_nI;
  wire  [DATA_WIDTH-1:0] out_internal;
  generate for(genvar i = 0; i < DATA_WIDTH; i = i + 1) begin
    assign out_nI[i] = (cla_s[i] & ctrl_s1[2]) | (cla_lh_cgen_s1[i] & ctrl_s1[1]);
    assign out_internal[i] = out_nI[i] ^ ctrl_s1[0];
  end endgenerate

  always_ff @(posedge clk /*or negedge reset_n*/) begin : ff_s2
    if(~reset_n) begin
      out_s2       <= '0;
      cout_s2      <= '0;
      //ctrl_s2      <= '0;
    end else if (pipe_active) begin
      out_s2       <= out_internal;
      cout_s2      <= cout_internal;
      //ctrl_s2      <= ctrl[3:0];
    end
  end

  // ----------------------------------------
  // Outputs
  // ----------------------------------------
  assign out  = out_en ? out_s2 : 'b0;
  assign cout = out_en ? cout_s2 : 'b0;

endmodule
