`include "uvm_macros.svh"
`include "design_parameters.sv"
`include "simulation_parameters.sv"

//tests have to be included to trigger compile
//so uvm can find them
`include "test_backend_0.sv"

//`timescale 100ps/1ps

module backend_tb_top import uvm_pkg::*; (
);
  logic clk;
  initial begin
    clk = 1'b0;
    forever begin
      #1 clk = ~clk;
    end
  end

  intf_backend intf (
    .clk(clk)
  );

  initial begin
    uvm_config_db #( virtual intf_backend )::set(null, "*", "intf_backend_top", intf);
  end

  `SIM_TB_MODULE(u_backend) #(
    .NUM_ICON_CHANNELS(2**`LOG2_NUM_ICON_CHANNELS),
    .NUM_EXEC_UNITS(2**`LOG2_NUM_EXEC_UNITS),
    .NUM_PARALLEL_INSTR_DISPATCHES(`NUM_PARALLEL_INSTR_DISPATCHES)
  ) tb (
    .clk(clk),
    .reset_n(intf.reset_n),

    //Dispatch bus
    //connects front end dispatch to all execution unit IQueues
    .instr_dispatch_i(intf.instr_dispatch_i),
    .instr_dispatch_valid_i(intf.instr_dispatch_valid_i),
    .dispatched_instr_alloc_euidx_i(intf.dispatched_instr_alloc_euidx_i),
    .instr_dispatch_ready_o(intf.instr_dispatch_ready_o),

    .icon_instr_dispatch_i(intf.icon_instr_dispatch_i),
    .icon_instr_dispatch_valid_i(intf.icon_instr_dispatch_valid_i),
    .icon_instr_dispatch_ready_o(intf.icon_instr_dispatch_ready_o)
  );

  initial begin
    run_test("backend_test_0");
  end
endmodule
