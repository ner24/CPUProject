`include "projectConfig/simulation_parameters.sv"

module alpu_with_cache #( //WIP
  parameter REG_WIDTH = 4
)(
  input  wire                   clk,
  input  wire                   reset_n,

  input  logic            [3:0] instr_i,
  input  wire   [REG_WIDTH-1:0] a_i,
  input  wire   [REG_WIDTH-1:0] b_i,
  input  wire                   cin_i,
  output wire   [REG_WIDTH-1:0] out_o,
  output wire                   cout_o
);


//`define ALPU_NAME alpu`VERIF_MODULE_SUFFIX 
  `SIM_TB_MODULE(alpu) #(
    .REG_WIDTH(REG_WIDTH)
  ) alpu (
    .clk(clk),
    .reset_n(reset_n),
    .instr_i(instr_i),
    .a_i(a_i),
    .b_i(b_i),
    .cin_i(cin_i),
    .out_o(out_o),
    .cout_o(cout_o)
  );

  /*`SIM_TB_MODULE(alpu_cache) #(

  ) cache (

  );*/

endmodule
