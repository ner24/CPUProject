`include "uvm_macros.svh"
`include "design_parameters.sv"
`include "simulation_parameters.sv"

//tests have to be included to trigger compile
//so uvm can find them
//`include "eu_tests/test_general.sv"
`include "eu_tests/test_rx0_add_rx1.sv"

//`timescale 100ps/1ps

module execution_unit_tb_top import uvm_pkg::*; (
);
  logic clk;
  initial begin
    clk = 1'b0;
    forever begin
      #1 clk = ~clk;
    end
  end

  intf_eu intf (
    .clk(clk)
  );

  initial begin
    `uvm_info("intf_eu_top", "Adding alpu top interface to uvm config", UVM_MEDIUM)
    //uvm_config_db_options::turn_on_tracing();
    uvm_config_db #( virtual intf_eu )::set(null, "*", "intf_eu_top", intf);
  end

  `SIM_TB_MODULE(execution_unit) #(
    .EU_IDX(0),
    .NUM_PARALLEL_INSTR_DISPATCHES(`NUM_PARALLEL_INSTR_DISPATCHES)
  ) tb (
    .clk      (clk),
    .reset_n  (intf.reset_n),
    
    .icon_rx0_i(intf.icon_rx0_i),
    .icon_rx0_resp_o(intf.icon_rx0_resp_o),
    .icon_rx1_i(intf.icon_rx1_i),
    .icon_rx1_resp_o(intf.icon_rx1_resp_o),
  
    .icon_tx_data_o(intf.icon_tx_data_o),
    .icon_tx_addr_i(intf.icon_tx_addr_i),
    .icon_tx_req_valid_i(intf.icon_tx_req_valid_i),
    .icon_tx_success_o(intf.icon_tx_success_o),

    .dispatched_instr_i(intf.dispatched_instr_i),
    .dispatched_instr_valid_i(intf.dispatched_instr_valid_i),
    .dispatched_instr_alloc_euidx_i(intf.dispatched_instr_alloc_euidx_i),
    .ready_for_next_instrs_o(intf.ready_for_next_instrs_o)
  );

  initial begin
    //run_test("execution_unit_test_general");
    run_test("execution_unit_test_rx0_add_rx1");
  end
endmodule
