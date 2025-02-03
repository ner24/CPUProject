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

  //interconnect
  input  wire type_icon_tx_channel icon_rx0_i,
  output wire type_icon_rx_channel icon_rx0_resp_o,
  input  wire type_icon_tx_channel icon_rx1_i,
  output wire type_icon_rx_channel icon_rx1_resp_o,
  
  //not using type_icon_tx_channel for tx because ports
  //go in different directions
  output wire type_exec_unit_data  icon_tx_data_o,
  input  wire type_exec_unit_addr  icon_tx_addr_i,
  input  wire                      icon_tx_req_valid_i,
  output wire                      icon_tx_success_o,

  //iqueue
  input  wire type_iqueue_entry    dispatched_instr_i,
  input  wire                      dispatched_instr_valid_i,
  output wire                      ready_for_next_instr_o
);
  
  intf_eu_cache #(
  ) intf (
    .clk(clk)
  );
  assign intf.reset_n      = reset_n;
  assign intf.icon_rx0_i     = icon_rx0_i;
  assign intf.icon_rx0_resp_o    = icon_rx0_resp_o;
  assign intf.icon_rx1_i = icon_rx1_i;
  assign intf.icon_rx1_resp_o    = icon_rx1_resp_o;
  assign intf.icon_tx_data_o = icon_tx_data_o;
  assign intf.icon_tx_addr_i = icon_tx_addr_i;
  assign intf.icon_tx_req_valid_i = icon_tx_req_valid_i;
  assign intf.icon_tx_success_o = icon_tx_success_o;
  assign intf.dispatched_instr_i = dispatched_instr_i;
  assign intf.dispatched_instr_valid_i = dispatched_instr_valid_i;
  assign intf.ready_for_next_instr_o = ready_for_next_instr_o;

  initial begin
    uvm_config_db #( virtual intf_alpu_cache #() )::set(null, "*", "intf_eu_cache", intf);
  end

  execution_unit #(
    .EU_IDX(EU_IDX)
  ) dut (
    .clk      (clk),
    .reset_n  (reset_n),
    
    .icon_rx0_i(icon_rx0_i),
    .icon_rx0_resp_o(icon_rx0_resp_o),
    .icon_rx1_i(icon_rx1_i),
    .icon_rx1_resp_o(icon_rx1_resp_o),
  
    .icon_tx_data_o(icon_tx_data_o),
    .icon_tx_addr_i(icon_tx_addr_i),
    .icon_tx_req_valid_i(icon_tx_req_valid_i),
    .icon_tx_success_o(icon_tx_success_o),

    .dispatched_instr_i(dispatched_instr_i),
    .dispatched_instr_valid_i(dispatched_instr_valid_i),
    .ready_for_next_instr_o(ready_for_next_instr_o)
  );

  // --------------------
  // VERIF
  // --------------------

endmodule
