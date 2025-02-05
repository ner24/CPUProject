interface intf_alu import pkg_dtypes::*; #(
) (
  input wire clk
);

  logic               reset_n;

  type_alu_channel_rx alu_rx_i;
  type_alu_channel_tx alu_tx_o;

  type_iqueue_opcode  curr_instr_i;
  logic               curr_instr_valid_i;

  logic               ready_for_next_instr_o;
    
endinterface
