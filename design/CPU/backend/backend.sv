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
  wire                     active_icon_channels [NUM_ICON_CHANNELS-1:0];
  wire                     tx_req_valid [NUM_ICON_CHANNELS-1:0];
  generate for(genvar i = 0; i < NUM_ICON_CHANNELS; i++) begin
    assign channel_success_lists[i]  = channels[i].success_list;
    assign channels[i].receiver_list = channel_receiver_lists[i];
    assign channels[i].src_addr      = channel_src_addrs[i];
    assign channels[i].active        = active_icon_channels[i];
    assign channels[i].tx_req_valid  = tx_req_valid[i];
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
    .tx_req_valid_o(tx_req_valid),
    .channel_active_o(active_icon_channels),
    .success_lists_i(channel_success_lists)
  );

  // ---------------------------
  // Instantiate exec units
  // ---------------------------
  type_icon_rx_channel_chside icon_rxx [NUM_EXEC_UNITS-1:0] [1:0];
  always_comb begin
    for(int i = 0; i < NUM_ICON_CHANNELS; i++) begin
      channels[i].data       = 'b0;
      channels[i].data_valid = 'b0;
      for (int eu_idx = 0; eu_idx < NUM_EXEC_UNITS; eu_idx++) begin
        //NOTE: the interfaces internally set these signals to all 0s when
        //eu tx is to not be used for this channel at that specific time
        for(int opx = 0; opx < 2; opx++) begin
          channels[i].data       |= icon_rxx[eu_idx][opx].data_rx;
          channels[i].data_valid |= icon_rxx[eu_idx][opx].data_valid_rx;
        end
      end
    end
  end

  generate for(genvar i = 0; i < NUM_ICON_CHANNELS; i++) begin
      for (genvar eu_idx = 0; eu_idx < NUM_EXEC_UNITS; eu_idx++) begin
        assign channels[i].success_list.eus[eu_idx*2] = icon_rxx[eu_idx][0].success;
        assign channels[i].success_list.eus[(eu_idx*2)+1] = icon_rxx[eu_idx][1].success;
      end
      //MMU not implemented so just tie to 1
      assign channels[i].success_list.receiver_str = 'b1;
      assign channels[i].success_list.receiver_mxreg = 'b1;
  end endgenerate

  //when dispatch bus is wider than eu accept bus, it is possible
  //that some instructions in batch will get accepted as there are not enough
  //lanes in the accept bus of a specific eu. In which case, the front end should stall
  //and try and dispatch the left over instructions. Front end should keep retrying until
  //entire batch gets dispatched and accepted into their designated EU IQueues
  //NOTE: leaving this comment here, but this is now handled in EU Alloc ILN
  wire [NUM_EXEC_UNITS-1:0] instr_dispatch_readys;
  assign instr_dispatch_ready_o = |instr_dispatch_readys;
  wire type_icon_rx_channel_chside [NUM_EXEC_UNITS-1:0] [1:0] icon_rx_glob [NUM_ICON_CHANNELS];

  generate for (genvar ch_idx = 0; ch_idx < NUM_ICON_CHANNELS; ch_idx++) begin
    assign channels[ch_idx] = |icon_rx_glob[ch_idx];
  end endgenerate

  generate for (genvar eu_idx = 0; eu_idx < NUM_EXEC_UNITS; eu_idx++) begin: g_eu
    wire type_icon_tx_channel [1:0] eu_rxx_ch [NUM_ICON_CHANNELS-1:0];
    wire type_icon_tx_rx_channel [1:0] eu_tx_ch  [NUM_ICON_CHANNELS-1:0];

    type_icon_tx_channel [1:0] eu_rxx;
    type_icon_rx_channel [1:0] eu_rxx_resp;
    type_icon_tx_rx_channel [1:0] eu_txx;
    type_icon_tx_rx_channel eu_tx;
    type_icon_tx_tx_channel eu_tx_resp;

    always_comb begin
      eu_rxx = 'b0;
      eu_txx = 'b0;
      for(int i = 0; i < NUM_ICON_CHANNELS; i++) begin
        eu_rxx |= eu_rxx_ch[i];
        eu_txx  |= eu_tx_ch[i];
      end
      eu_tx = eu_txx[0] | eu_txx[1];
    end

    //for each eu two icon interfaces (for op0 and op1) for each channel
    for (genvar ch_idx = 0; ch_idx < NUM_ICON_CHANNELS; ch_idx++) begin
      wire force_disable_op1_tx;
      for (genvar opx = 0; opx < 2; opx++) begin
        wire type_icon_tx_channel_chside icon_tx;
        assign icon_tx.req_valid     = channels[ch_idx].active & channels[ch_idx].receiver_list[(2*eu_idx) + opx];
        assign icon_tx.req_tx_valid  = channels[ch_idx].tx_req_valid;
        assign icon_tx.data_tx       = channels[ch_idx].data;
        assign icon_tx.data_valid_tx = channels[ch_idx].data_valid;
        assign icon_tx.src_addr      = channels[ch_idx].src_addr;

        wire type_icon_rx_channel_chside icon_rx;
        /*assign channels[ch_idx].data                           = icon_rx.data_rx;
        assign channels[ch_idx].data_valid                     = icon_rx.data_valid_rx;
        assign channels[ch_idx].success_list[(2*eu_idx) + opx] = icon_rx.success;*/
        assign icon_rx_glob[ch_idx][eu_idx][opx] = icon_rx;

        if (opx == 0) begin
          assign force_disable_op1_tx = icon_tx.req_valid;
        end

        back_iconch_interface #(
          .EU_IDX(eu_idx)
        ) icon_if_0 (
          //icon side
          .icon_tx_i(icon_tx),
          .icon_rx_o(icon_rx),

          //eu rx side
          .eu_rx_o(eu_rxx_ch[ch_idx][opx]),
          .eu_rx_resp_i(eu_rxx_resp[opx]),
          
          //eu tx side
          .eu_tx_o(eu_tx_ch[ch_idx][opx]),
          .eu_tx_resp_i(eu_tx_resp),

          //extra control
          .force_disable_tx(force_disable_op1_tx)
        );
      end
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
      .icon_tx_data_o(eu_tx_resp.data_tx),
      .icon_tx_addr_i(eu_tx.src_addr_tx),
      .icon_tx_req_valid_i(eu_tx.valid_tx),
      .icon_tx_success_o(eu_tx_resp.success_tx),

      //instruction dispatch and ready
      .dispatched_instr_i(instr_dispatch_i),
      .dispatched_instr_valid_i(instr_dispatch_valid_i),
      .ready_for_next_instrs_o(instr_dispatch_readys[eu_idx]), //if not, stall dispatch
      .dispatched_instr_alloc_euidx_i(dispatched_instr_alloc_euidx_i)
    );

  end endgenerate

endmodule

/*
    wire type_exec_unit_data  eu_tx_data;
    wire type_exec_unit_addr  eu_tx_addr;
    wire type_exec_unit_addr  eu_tx_addr_opx [1:0];
    wire                      eu_tx_valid;
    wire                      eu_tx_valid_opx [1:0];
    wire                      eu_tx_resp_data_valid;
    
    assign eu_tx_addr = eu_tx_addr_opx[0] | eu_tx_addr_opx[1];
    assign eu_tx_valid = eu_tx_valid_opx[0] | eu_tx_valid_opx[1];
    */

/*type_icon_tx_channel_chside icon_txs [1:0];
    
    always_comb begin
      for (int opx = 0; opx < 2; opx++) begin
        icon_txs[opx].req_valid     = 'b0;
        icon_txs[opx].data_tx       = 'b0;
        icon_txs[opx].data_valid_tx = 'b0;
        icon_txs[opx].src_addr      = 'b0;
        for(int i = 0; i < NUM_ICON_CHANNELS; i++) begin
          //NOTE: originally, the idea was for the sender to also be in the one hot list. It would work out itself that it
          //was the src by comparing the euidx. This is no longer the case but the icon channel interfaces havnt been updated
          //yet. So, req_valid is used for senders and recievers, and the icon channel will work out its the sender. This should
          //be changed when the euidx address field is eventually removed and channel interfaces updated.
          logic req_valid;
          req_valid |=  tx_req_valid[i] & active_icon_channels[i] ?
                        channels[i].receiver_list[(2*eu_idx) + opx] | (channels[i].src_addr.euidx == eu_idx)
                        : 'b0;
          icon_txs[opx].req_valid     |= req_valid;
          icon_txs[opx].data_tx       |= req_valid ? channels[i].data : 'b0;
          icon_txs[opx].data_valid_tx |= req_valid ? channels[i].data_valid : 'b0;
          icon_txs[opx].src_addr      |= req_valid & (channels[i].src_addr.euidx == eu_idx) ? channels[i].src_addr : 'b0;
        end
      end
    end*/

    //type_icon_rx_channel_chside icon_rxx [1:0];
    //assign icon_rx[eu_idx] = icon_rxx[0] | icon_rxx[1];

    /*.eu_tx_resp_data_i(eu_tx_data),
          .eu_tx_addr_o(eu_tx_addr_opx[opx]),
          .eu_tx_valid_o(eu_tx_valid_opx[opx]),
          .eu_tx_resp_data_valid_i(eu_tx_resp_data_valid),*/
