`include "design_parameters.sv"

interface intf_eu import pkg_dtypes::*; #(
) (
  input wire clk
);

  localparam NUM_PARALLEL_INSTR_DISPATCHES = `NUM_PARALLEL_INSTR_DISPATCHES;
  localparam LOG2_NUM_EXEC_UNITS = `LOG2_NUM_EXEC_UNITS;

  logic               reset_n;

  //interconnect
  type_icon_tx_channel icon_rx0_i;
  type_icon_rx_channel icon_rx0_resp_o;
  type_icon_tx_channel icon_rx1_i;
  type_icon_rx_channel icon_rx1_resp_o;
  
  //not using type_icon_tx_channel for tx because ports
  //go in different directions
  type_exec_unit_data  icon_tx_data_o;
  type_exec_unit_addr  icon_tx_addr_i;
  logic                icon_tx_req_valid_i;
  logic                icon_tx_success_o;

  //iqueue
  type_iqueue_entry    dispatched_instr_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic                dispatched_instr_valid_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic [LOG2_NUM_EXEC_UNITS-1:0] dispatched_instr_alloc_euidx_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic                ready_for_next_instrs_o;
    
endinterface
