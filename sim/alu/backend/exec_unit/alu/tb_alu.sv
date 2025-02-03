import uvm_pkg::*;
`include "uvm_macros.svh"

`include "simulation_parameters.sv"
`include "design_parameters.sv"

module `SIM_TB_MODULE(alu) import uvm_pkg::*; import pkg_dtypes::*; #(
  parameter USE_PIPELINED_ALU = `ALU_USE_PIPELINED_ALU
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire type_alu_channel_rx alu_rx_i,
  output wire type_alu_channel_tx alu_tx_o,

  input  wire type_iqueue_entry curr_instr_i,
  input  wire                   curr_instr_valid_i
);

  alu #(
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    
    .alu_rx_i(alu_rx),
    .alu_tx_o(alu_tx),

    .curr_instr_i(curr_instr),
    .curr_instr_valid_i(curr_instr_to_exec_valid)
  );

  intf_alu #() intf (
    .clk(clk)
  );
  assign intf.reset_n            = reset_n;
  assign intf.alu_rx_i           = alu_rx_i;
  assign intf.alu_tx_o           = alu_tx_o;
  assign intf.curr_instr_i       = curr_instr_i;
  assign intf.curr_instr_valid_i = curr_instr_valid_i;

  initial begin
    uvm_config_db #( virtual intf_alpu #() )::set(null, "*", "intf_alu", intf);
  end

  // --------------------
  // VERIF
  // --------------------
  
  sva_alu_op #(
    .USE_PIPELINED_ALU(USE_PIPELINED_ALU)
  ) u_sva_alu_op (
    .alu_clk    (clk),
    .alu_resetn (intf.reset_n),
    
    .alu_rx_i(alu_rx),
    .alu_tx_o(alu_tx),

    .curr_instr_i(curr_instr),
    .curr_instr_valid_i(curr_instr_to_exec_valid)
  );

endmodule
