module eu_IQueue import pkg_dtypes::*; #(
  parameter LOG2_QUEUE_LENGTH = 4
) (
  input  wire clk,
  input  wire reset_n,

  input  wire type_iqueue_entry dispatched_instr_i,
  input  wire                   dispatched_instr_valid_i,
  
  output wire                   is_full_o, //cannot accept entries when full
  output wire type_iqueue_entry curr_instr_to_exec_o,
  input  wire                   ready_for_next_instr_i, //tell queue to stall if not ready
  output wire                   curr_instr_to_exec_valid_o
);

  fifo_buffer #(
    .LOG2_QUEUE_LENGTH(LOG2_QUEUE_LENGTH),
    .DATA_WIDTH($bits(curr_instr_to_exec_o))
  ) ram (
    .clk(clk),
    .reset_n(reset_n),

    .wdata_i(dispatched_instr_i),
    .wvalid_i(dispatched_instr_valid_i),

    .rdata_o(curr_instr_to_exec_o),
    .rready_i(ready_for_next_instr_i),

    .full_o(is_full_o),
    .empty_o(curr_instr_to_exec_valid_o)
  );

endmodule
