//`include "alu_parameters.sv"

module alpu_bd_test #(
  parameter REG_WIDTH = 4,
  parameter USE_PIPELINED_ALPU = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire             [3:0] instr_i,
  input  wire   [REG_WIDTH-1:0] a_i,
  input  wire   [REG_WIDTH-1:0] b_i,
  input  wire                   cin_i,
  output wire   [REG_WIDTH-1:0] out_o,
  output wire                   cout_o
);

  alpu test (
    .clk(clk),
    .reset_n(reset_n),
    .instr_i(instr_i),
    .a_i(a_i),
    .b_i(b_i),
    .cin_i(cin_i),
    .out_o(out_o),
    .cout_o(cout_o)
  );

endmodule