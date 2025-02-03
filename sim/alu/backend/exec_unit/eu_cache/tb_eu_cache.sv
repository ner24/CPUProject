import uvm_pkg::*;
`include "uvm_macros.svh"

`include "design_parameters.sv"
`include "simulation_parameters.sv"
`include "seqItem_alpu_cache.sv"

//typedef class eu_cache_monitor;

module `SIM_TB_MODULE(eu_cache) import uvm_pkg::*; import pkg_dtypes::*; #(
  parameter EU_IDX = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  // ALPU interface
  // 2 buses: operands read, result write
  output wire type_alu_channel_rx alu_rx_o,
  input  wire type_alu_channel_tx alu_tx_i,

  // Interconnect interface
  // 3 channels: operands write, operand read
  input  wire type_icon_tx_channel    icon_w0_i, //for op0
  output wire type_icon_rx_channel icon_w0_rx_o,
  input  wire type_icon_tx_channel    icon_w1_i, //for op1
  output wire type_icon_rx_channel icon_w1_rx_o,
  
  //not using type_icon_tx_channel since attributes go in different directions
  output wire type_exec_unit_data  icon_rdata_o,
  input  wire type_exec_unit_addr  icon_raddr_i,
  input  wire                      icon_rvalid_i,
  output wire                      icon_rsuccess_o,

  // Instruction reqeusts (from IQUEUE)
  input  wire type_iqueue_entry curr_instr_i
);
  
  intf_eu_cache #(
  ) intf (
    .clk(clk)
  );
  assign intf.reset_n      = reset_n;
  assign intf.alu_rx_o     = alu_rx_o;
  assign intf.icon_w0_i    = icon_w0_i;
  assign intf.icon_w0_rx_o = icon_w0_rx_o;
  assign intf.icon_w1_i    = icon_w1_i;
  assign intf.icon_w1_rx_o = icon_w1_rx_o;
  assign intf.icon_rdata_o = icon_rdata_o;
  assign intf.icon_raddr_i = icon_raddr_i;
  assign intf.icon_rvalid_i = icon_rvalid_i;
  assign intf.icon_rsuccess_o = icon_rsuccess_o;

  initial begin
    uvm_config_db #( virtual intf_alpu_cache #() )::set(null, "*", "intf_eu_cache", intf);
  end

  eu_cache #(
    .EU_IDX(EU_IDX)
  ) dut (
    .clk      (clk),
    .reset_n  (reset_n),
    
    .alu_rx_o(alu_rx_o),
    .alu_tx_i(alu_tx_i),

    .icon_w0_i(icon_w0_i),
    .icon_w0_rx_o(icon_w0_rx_o),
    .icon_w1_i(icon_w1_i),
    .icon_w1_rx_o(icon_w1_rx_o),
  
    .icon_rdata_o(icon_rdata_o),
    .icon_raddr_i(icon_raddr_i),
    .icon_rvalid_i(icon_rvalid_i),
    .icon_rsuccess_o(icon_rsuccess_o),

    .curr_instr_i(curr_instr_i)
  );

  // --------------------
  // VERIF
  // --------------------

endmodule
