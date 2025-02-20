`include "design_parameters.sv"

interface intf_alu import pkg_dtypes::*; #(
) (
  input wire clk
);
  localparam NUM_PARALLEL_INSTR_DISPATCHES = `NUM_PARALLEL_INSTR_DISPATCHES;
  localparam LOG2_NUM_EXEC_UNITS = `LOG2_NUM_EXEC_UNITS;
  localparam NUM_ICON_CHANNELS = 2**`LOG2_NUM_ICON_CHANNELS;

  logic                   reset_n;

  //Dispatch bus
  //connects front end dispatch to all execution unit IQueues
  type_iqueue_entry               instr_dispatch_i       [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic                   				instr_dispatch_valid_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic [LOG2_NUM_EXEC_UNITS-1:0] dispatched_instr_alloc_euidx_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic                           instr_dispatch_ready_o;

  type_icon_instr   icon_instr_dispatch_i       [NUM_ICON_CHANNELS-1:0];
  logic             icon_instr_dispatch_valid_i [NUM_ICON_CHANNELS-1:0];
  logic             icon_instr_dispatch_ready_o [NUM_ICON_CHANNELS-1:0];
    
endinterface
