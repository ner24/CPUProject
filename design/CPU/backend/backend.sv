`include "simulation_parameters.sv"

module u_backend import pkg_dtypes::*; #(
  parameter NUM_ICON_CHANNELS = 4,
  parameter NUM_EXEC_UNITS = 4,

  //this should equal the width of the rename ILN in the front end
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

  //Store buffer output
  //interconnect channel which sends data to MMU for str handling

  //mx register write
  //interconnect channel for writing values to mx registers in the MMU

);
  // ---------------------------
  // Interconnect channels
  // ---------------------------
  type_icon_channel channels [NUM_ICON_CHANNELS-1:0];

  // ---------------------------
  // Interconnect controller
  // ---------------------------
  type_icon_receivers_list channel_success_lists  [NUM_ICON_CHANNELS-1:0];
  type_icon_receivers_list channel_receiver_lists [NUM_ICON_CHANNELS-1:0];
  type_exec_unit_addr      channel_src_addrs      [NUM_ICON_CHANNELS-1:0];
  generate for(genvar i = 0; i < NUM_ICON_CHANNELS; i++) begin
    assign channel_success_lists[i]  = channels[i].success_list;
    assign channels[i].receiver_list = channel_receiver_lists[i];
    assign channels[i].src_addr      = channel_src_addrs[i];
  end endgenerate

  back_icon_controller #(
    .NUM_ICON_CHANNELS(NUM_ICON_CHANNELS)
  ) icon_ctrl (
    .clk(clk),
    .reset_n(reset_n),

    .icon_instr_dispatch_i(icon_instr_dispatch_i),
    .icon_instr_dispatch_valid_i(icon_instr_dispatch_valid_i),
    .icon_instr_dispatch_ready_o(icon_instr_dispatch_ready_o),

    .src_addrs_o(channel_src_addrs),
    .receiver_lists_o(channel_receiver_lists),
    .success_lists_i(channel_success_lists)
  );

  // ---------------------------
  // Instantiate exec units
  // ---------------------------
  type_icon_rx_channel_chside icon_rx [NUM_EXEC_UNITS-1:0];
  always_comb begin
    for(int i = 0; i < NUM_ICON_CHANNELS; i++) begin
      channels[i].data       = 'b0;
      channels[i].data_valid = 'b0;
      for (int eu_idx = 0; eu_idx < NUM_EXEC_UNITS; eu_idx++) begin
        //NOTE: the interfaces internally set these signals to all 0s when
        //eu tx is to not be used for this channel at that specific time
        channels[i].data       |= icon_rx[eu_idx].data_rx;
        channels[i].data_valid |= icon_rx[eu_idx].data_valid_rx;
      end
    end
  end

  generate for(genvar i = 0; i < NUM_ICON_CHANNELS; i++) begin
      for (genvar eu_idx = 0; eu_idx < NUM_EXEC_UNITS; eu_idx++) begin
        assign channels[i].success_list.eus[eu_idx] = icon_rx[eu_idx].success;
      end
      //MMU not implemented so just tie to 0
      assign channels[i].success_list.receiver_str = 'b0;
      assign channels[i].success_list.receiver_mxreg = 'b0;
  end endgenerate

  //when dispatch bus is wider than eu accept bus, it is possible
  //that some instructions in batch will get accepted as there are not enough
  //lanes in the accept bus of a specific eu. In which case, the front end should stall
  //and try and dispatch the left over instructions. Front end should keep retrying until
  //entire batch gets dispatched and accepted into their designated EU IQueues
  //NOTE: leaving this comment here, but this is now handled in EU Alloc ILN
  wire [NUM_EXEC_UNITS-1:0] instr_dispatch_readys;
  assign instr_dispatch_ready_o = |instr_dispatch_readys;
  generate for (genvar eu_idx = 0; eu_idx < NUM_EXEC_UNITS; eu_idx++) begin: g_eu
    type_icon_tx_channel_chside icon_txs [1:0];
    
    always_comb begin
      for (int opx = 0; opx < 2; opx++) begin
        icon_txs[opx].req_valid     = 'b0;
        icon_txs[opx].data_tx       = 'b0;
        icon_txs[opx].data_valid_tx = 'b0;
        icon_txs[opx].src_addr      = 'b0;
        for(int i = 0; i < NUM_ICON_CHANNELS; i++) begin
          icon_txs[opx].req_valid     |= channels[i].receiver_list[(2*eu_idx) + opx];
          icon_txs[opx].data_tx       |= channels[i].data;
          icon_txs[opx].data_valid_tx |= channels[i].data_valid;
          icon_txs[opx].src_addr      |= channels[i].src_addr;
        end
      end
    end
    
    wire type_exec_unit_data  eu_tx_data;
    wire type_exec_unit_addr  eu_tx_addr;
    wire type_exec_unit_addr  eu_tx_addr_opx [1:0];
    wire                      eu_tx_valid;
    wire                      eu_tx_valid_opx [1:0];
    wire                      eu_tx_resp_data_valid;
    
    assign eu_tx_addr = eu_tx_addr_opx[0] | eu_tx_addr_opx[1];
    assign eu_tx_valid = eu_tx_valid_opx[0] | eu_tx_valid_opx[1];

    wire type_icon_tx_channel eu_rxx      [1:0];
    wire                      eu_rxx_resp [1:0];

    type_icon_rx_channel_chside icon_rxx [1:0];
    assign icon_rx[eu_idx] = icon_rxx[0] | icon_rxx[1];

    //two icon interfaces (for op0 and op1) for each eu
    for (genvar opx = 0; opx < 2; opx++) begin
      back_iconch_interface #(
        .EU_IDX(eu_idx)
      ) icon_if_0 (
        //icon side
        .icon_tx_i(icon_txs[opx]),
        .icon_rx_o(icon_rxx[opx]),

        //eu rx side
        .eu_rx_o(eu_rxx[opx]),
        .eu_rx_resp_i(eu_rxx_resp[opx]),
        
        //eu tx side
        .eu_tx_resp_data_i(eu_tx_data),
        .eu_tx_addr_o(eu_tx_addr_opx[opx]),
        .eu_tx_valid_o(eu_tx_valid_opx[opx]),
        .eu_tx_resp_data_valid_i(eu_tx_resp_data_valid),

        //extra control
        .force_disable_tx(opx ? icon_txs[0].req_valid : 1'b0)
      );
    end

    `SIM_TB_MODULE(execution_unit) #( //WIP. THis module without the IQueue only exists for verif purposes
      .NUM_PARALLEL_INSTR_DISPATCHES(NUM_PARALLEL_INSTR_DISPATCHES),
      .EU_IDX(eu_idx)
    ) eu (
      .clk(clk),
      .reset_n(reset_n),

      //icon rx
      .icon_rx0_i(eu_rxx[0]),
      .icon_rx0_resp_o(eu_rxx_resp[0]),
      .icon_rx1_i(eu_rxx[1]),
      .icon_rx1_resp_o(eu_rxx_resp[1]),
      
      //icon tx
      .icon_tx_data_o(eu_tx_data),
      .icon_tx_addr_i(eu_tx_addr),
      .icon_tx_req_valid_i(eu_tx_valid),
      .icon_tx_success_o(eu_tx_resp_data_valid),

      //instruction dispatch and ready
      .dispatched_instr_i(instr_dispatch_i),
      .dispatched_instr_valid_i(instr_dispatch_valid_i),
      .ready_for_next_instrs_o(instr_dispatch_readys[eu_idx]), //if not, stall dispatch
      .dispatched_instr_alloc_euidx_i(dispatched_instr_alloc_euidx_i)
    );

  end endgenerate

endmodule
