interface intf_alu import pkg_dtypes::*; #(
) (
  input wire clk
);

  logic               reset_n;

  type_alu_channel_rx alu_rx_i;
  type_alu_channel_tx alu_tx_o;

  type_iqueue_entry curr_instr_i;
  logic             curr_instr_valid_i;

  initial begin
    reset_n <= 1'b0;
  end
    
endinterface
