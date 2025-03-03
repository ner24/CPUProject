import uvm_pkg::*;
`include "uvm_macros.svh"

`include "simulation_parameters.sv"
`include "design_parameters.sv"

module `SIM_TB_MODULE(alu) import uvm_pkg::*; import pkg_dtypes::*; #(
  parameter DATA_WIDTH = `WORD_WIDTH,
  parameter USE_PIPELINED_ALU = `ALU_USE_PIPELINED_ALU
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire type_alu_channel_rx alu_rx_i,
  output wire type_alu_channel_tx alu_tx_o,

  input  wire type_iqueue_opcode curr_instr_i,
  input  wire                   curr_instr_valid_i,

  output wire                     ready_for_next_instr_o
);

  alu #(
    .DATA_WIDTH(DATA_WIDTH),
    .USE_PIPELINED_ALU(USE_PIPELINED_ALU)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    
    .alu_rx_i(alu_rx_i),
    .alu_tx_o(alu_tx_o),

    .curr_instr_i(curr_instr_i),
    .curr_instr_valid_i(curr_instr_valid_i),

    .ready_for_next_instr_o(ready_for_next_instr_o)
  );

  intf_alu intf (
    .clk(clk)
  );
  assign intf.reset_n            = reset_n;
  assign intf.alu_rx_i           = alu_rx_i;
  assign intf.alu_tx_o           = alu_tx_o;
  assign intf.curr_instr_i       = curr_instr_i;
  assign intf.curr_instr_valid_i = curr_instr_valid_i;
  assign intf.ready_for_next_instr_o = ready_for_next_instr_o;

  initial begin
    uvm_config_db #( virtual intf_alu )::set(null, "*", "intf_alu", intf);
  end

  // --------------------
  // VERIF
  // --------------------
  
  sva_alu_op #(
    .USE_PIPELINED_ALU(USE_PIPELINED_ALU)
  ) u_sva_alu_op (
    .alu_clk    (clk),
    .alu_resetn (intf.reset_n),
    
    .alu_rx_i(alu_rx_i),
    .alu_tx_o(alu_tx_o),

    .curr_instr_i(curr_instr_i),
    .curr_instr_valid_i(curr_instr_valid_i)
  );

endmodule
