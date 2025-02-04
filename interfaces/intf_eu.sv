interface intf_eu import pkg_dtypes::*; #(
) (
  input wire clk
);

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
  type_iqueue_entry    dispatched_instr_i;
  logic                dispatched_instr_valid_i;
  logic                ready_for_next_instr_o;
    
endinterface
