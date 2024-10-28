`include "simulation_parameters.sv"

module alpu_with_cache #( //WIP
  parameter REG_WIDTH = 4,
  parameter OPERAND_WIDTH = 4
)(
  input  wire                   clk,
  input  wire                   reset_n,

  
  input  wire   [REG_WIDTH-1:0] a_i,
  input  wire   [REG_WIDTH-1:0] b_i,
  output wire   [REG_WIDTH-1:0] out_o,

  //Instruction input (from IQueue)
  input  wire                [3:0] instr_i,
  input  wire  [OPERAND_WIDTH-1:0] op1_i,
  input  wire  [OPERAND_WIDTH-1:0] op2_i,
  input  wire  [OPERAND_WIDTH-1:0] opd_i,

  //Read out (communication to other caches
  //or back to front end)
  output wire  [OPERAND_WIDTH-1:0] op1
);

  wire [1:0] flags;
  `SIM_TB_MODULE(alpu) #(
    .REG_WIDTH(REG_WIDTH)
  ) alpu (
    .clk(clk),
    .reset_n(reset_n),
    .instr_i(instr_i),
    .a_i(a_i),
    .b_i(b_i),
    .cin_i(flags[0]),
    .out_o(out_o),
    .cout_o(flags[1])
  );

  `SIM_TB_MODULE(alpu_cache) #(
    .ADDR_WIDTH(2), //for 4 entries
    .DATA_WIDTH(REG_WIDTH)
  ) cache (
    .clk      (clk),
    .reset_n  (reset_n),
    .addr_i   (addr_i),
    .wdata_i  (wdata_i),
    .ce_i     (ce_i),
    .we_i     (we_i),
    .rdata_o  (rdata_o),
    .rvalid_o (rvalid_o),
    .wack_o   (wack_o)
  );

endmodule
