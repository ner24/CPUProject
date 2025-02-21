module back_icon_controller import pkg_dtypes::*; #(
  parameter NUM_ICON_CHANNELS = 4,
  parameter LOG2_QUEUE_LENGTH = 4
) (
  input  wire clk,
  input  wire reset_n,

  //Front end side
  //each channel will have a dedicated instruction queue
  //front end can send up to NUM_ICON_CHANNELS instructions in 1 cycle
  input  wire type_icon_instr   icon_instr_dispatch_i       [NUM_ICON_CHANNELS-1:0],
  input  wire                   icon_instr_dispatch_valid_i [NUM_ICON_CHANNELS-1:0],
  output wire                   icon_instr_dispatch_ready_o [NUM_ICON_CHANNELS-1:0],

  //Icon side
  //NOTE: output all 0s if instr not valid
  output wire type_exec_unit_addr      src_addrs_o      [NUM_ICON_CHANNELS-1:0],
  output wire type_icon_receivers_list receiver_lists_o [NUM_ICON_CHANNELS-1:0],
  input  wire type_icon_receivers_list success_lists_i  [NUM_ICON_CHANNELS-1:0]

);
  // ---------------------------
  // success list latches
  // ---------------------------
  type_icon_receivers_list success_lists_latched [NUM_ICON_CHANNELS-1:0];
  generate for(genvar ch_idx = 0; ch_idx < NUM_ICON_CHANNELS; ch_idx++) begin
    always_ff @(posedge clk) begin
      if(~reset_n) begin
        success_lists_latched[ch_idx] = 'b0;
      end else begin
        success_lists_latched[ch_idx] |= success_lists_i[ch_idx];
      end
    end
  end endgenerate

  // -------------------------------
  // Channel instruction queues
  // -------------------------------
  wire                 ready_for_next_instr [NUM_ICON_CHANNELS-1:0];
  wire type_icon_instr curr_instrs          [NUM_ICON_CHANNELS-1:0];
  wire                 curr_instrs_valid    [NUM_ICON_CHANNELS-1:0];
  generate for(genvar ch_idx = 0; ch_idx < NUM_ICON_CHANNELS; ch_idx++) begin
    wire is_queue_full;
    assign icon_instr_dispatch_ready_o[ch_idx] = ~is_queue_full;
    back_icon_IQueue #(
      .LOG2_QUEUE_LENGTH(LOG2_QUEUE_LENGTH)
    ) channel_iqueue (
      .clk(clk),
      .reset_n(reset_n),

      .dispatched_instr_i(icon_instr_dispatch_i[ch_idx]),
      .dispatched_instr_valid_i(icon_instr_dispatch_valid_i[ch_idx]),
      
      .is_full_o(is_queue_full), //cannot accept entries when full
      .curr_instr_to_exec_o(curr_instrs[ch_idx]),
      .ready_for_next_instr_i(ready_for_next_instr[ch_idx]), //tell queue to stall if not ready
      .curr_instr_to_exec_valid_o(curr_instrs_valid[ch_idx])
    );
  end endgenerate

  // -------------------------------
  // Arbitration ILN and outputs
  // -------------------------------
  type_icon_receivers_list available_receivers_list_ics [NUM_ICON_CHANNELS-1:0];

  assign available_receivers_list_ics[0] = {$bits(type_icon_receivers_list){1'b1}};
  generate for(genvar ch_idx = 0; ch_idx < NUM_ICON_CHANNELS; ch_idx++) begin

    assign receiver_lists_o[ch_idx] = curr_instrs_valid[ch_idx] ?
                                        available_receivers_list_ics[ch_idx]
                                        & (~success_lists_latched[ch_idx])
                                        & curr_instrs[ch_idx].receiver_list
                                      : 'b0;
    if (ch_idx != (NUM_ICON_CHANNELS-1)) begin
      assign available_receivers_list_ics[ch_idx + 1] = ~receiver_lists_o[ch_idx];
    end

    assign src_addrs_o[ch_idx] = curr_instrs_valid[ch_idx] ?
                                   curr_instrs[ch_idx].src_addr
                                 : 'b0;

    assign ready_for_next_instr[ch_idx] = &success_lists_latched[ch_idx];
  end endgenerate

endmodule
