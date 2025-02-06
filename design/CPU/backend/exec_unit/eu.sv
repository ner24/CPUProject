`include "simulation_parameters.sv"
`include "design_parameters.sv"

module execution_unit import pkg_dtypes::*; #( //WIP. THis module without the IQueue only exists for verif purposes
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
  output wire                      ready_for_next_instr_o //if not, stall dispatch
);

  wire type_iqueue_entry curr_instr;

  wire type_alu_channel_rx alu_rx;
  wire type_alu_channel_tx alu_tx;

  assign alu_rx.opd_addr = curr_instr.opd;

  wire curr_instr_to_exec_valid;
  wire ready_for_next_instr;

  `SIM_TB_MODULE(alu) #(
  ) alu (
    .clk(clk),
    .reset_n(reset_n),
    
    .alu_rx_i(alu_rx),
    .alu_tx_o(alu_tx),

    .curr_instr_i(curr_instr.opcode),
    .curr_instr_valid_i(curr_instr_to_exec_valid),

    .ready_for_next_instr_o(ready_for_next_instr)
  );

  eu_IQueue #(
    .LOG2_QUEUE_LENGTH(`EU_LOG2_IQUEUE_LENGTH)
  ) iqueue (
    .clk(clk),
    .reset_n(reset_n),
    .dispatched_instr_i(dispatched_instr_i),
    .dispatched_instr_valid_i(dispatched_instr_valid_i),
    
    .is_full_o(ready_for_next_instr_o), //cannot accept entries when full
    .curr_instr_to_exec_o(curr_instr),
    //tell queue to stall if not ready due to:
    //opd not being stored yet (stall on receiver)
    .ready_for_next_instr_i(ready_for_next_instr),
    .curr_instr_to_exec_valid_o(curr_instr_to_exec_valid)
  );

  `SIM_TB_MODULE(eu_cache) #(
    .EU_IDX(EU_IDX)
  ) cache (
    .clk      (clk),
    .reset_n  (reset_n),
    
    //ALU interface
    .alu_rx_o(alu_rx),
    .alu_tx_i(alu_tx),

    // Interconnect interface
    // 3 channels: operands write, operand read
    .icon_w0_i(icon_rx0_i), //for op0
    .icon_w0_rx_o(icon_rx0_resp_o),
    .icon_w1_i(icon_rx1_i), //for op1
    .icon_w1_rx_o(icon_rx1_resp_o),
  
    .icon_rdata_o(icon_tx_data_o),
    .icon_raddr_i(icon_tx_addr_i),
    .icon_rvalid_i(icon_tx_req_valid_i),
    .icon_rsuccess_o(icon_tx_success_o),

    // Instruction reqeusts (from IQUEUE)
    .curr_instr_i(curr_instr),
    .curr_instr_valid_i(curr_instr_to_exec_valid)
  );

endmodule
