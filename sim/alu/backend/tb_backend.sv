import uvm_pkg::*;
`include "uvm_macros.svh"

`include "design_parameters.sv"
`include "simulation_parameters.sv"

//typedef class eu_cache_monitor;

module `SIM_TB_MODULE(u_backend) import uvm_pkg::*; import pkg_dtypes::*; #(
  parameter NUM_ICON_CHANNELS = 4,
  parameter NUM_EXEC_UNITS = 4,

  //this should equal the width of the rename ILN in the front end (i.e. the instuction batch size)
  parameter NUM_PARALLEL_INSTR_DISPATCHES = 4
) (
  input  wire                   clk,
  input  wire                   reset_n,

  //Dispatch bus
  //connects front end dispatch to all execution unit IQueues
  input  wire type_iqueue_entry instr_dispatch_i       [NUM_PARALLEL_INSTR_DISPATCHES-1:0],
  input  wire                   instr_dispatch_valid_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0],
  input  wire [LOG2_NUM_EXEC_UNITS-1:0] dispatched_instr_alloc_euidx_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0],
  output wire                   instr_dispatch_ready_o,

  input  wire type_icon_instr   icon_instr_dispatch_i       [NUM_ICON_CHANNELS-1:0],
  input  wire                   icon_instr_dispatch_valid_i [NUM_ICON_CHANNELS-1:0],
  output wire                   icon_instr_dispatch_ready_o [NUM_ICON_CHANNELS-1:0]
);
  
  intf_backend intf (
    .clk(clk)
  );
  assign intf.reset_n      = reset_n;
  assign intf.instr_dispatch_i     = instr_dispatch_i;
  assign intf.instr_dispatch_valid_i    = instr_dispatch_valid_i;
  assign intf.dispatched_instr_alloc_euidx_i = dispatched_instr_alloc_euidx_i;
  assign intf.instr_dispatch_ready_o    = instr_dispatch_ready_o;
  assign intf.icon_instr_dispatch_i = icon_instr_dispatch_i;
  assign intf.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid_i;
  assign intf.icon_instr_dispatch_ready_o = icon_instr_dispatch_ready_o;

  initial begin
    uvm_config_db #( virtual intf_backend )::set(null, "*", "intf_backend", intf);
  end

  u_backend #(
    .NUM_EXEC_UNITS(NUM_EXEC_UNITS),
    .NUM_PARALLEL_INSTR_DISPATCHES(NUM_PARALLEL_INSTR_DISPATCHES),
    .NUM_ICON_CHANNELS(NUM_ICON_CHANNELS)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),

    //Dispatch bus
    //connects front end dispatch to all execution unit IQueues
    .instr_dispatch_i(instr_dispatch_i),
    .instr_dispatch_valid_i(instr_dispatch_valid_i),
    .dispatched_instr_alloc_euidx_i(dispatched_instr_alloc_euidx_i),
    .instr_dispatch_ready_o(instr_dispatch_ready_o),

    .icon_instr_dispatch_i(icon_instr_dispatch_i),
    .icon_instr_dispatch_valid_i(icon_instr_dispatch_valid_i),
    .icon_instr_dispatch_ready_o(icon_instr_dispatch_ready_o)
  );

  // --------------------
  // VERIF
  // --------------------

endmodule


