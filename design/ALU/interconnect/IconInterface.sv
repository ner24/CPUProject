module eu_iconIntf import exec_unit_dtypes::*; #(
  localparam NUM_PORTS = 3,
  parameter EU_IDX = 0 //must equal alpu_cache ALU IDX.
) (
  //each interface will have
  inout  wire type_icon_channel channel_port [0:NUM_PORTS-1], //0 = tx, 1 = rx0, 2 = rx1

  output wire type_icon_tx_channel x_rx0_o,
  input  wire                      x_rx0_ready_i,
  output wire type_icon_tx_channel x_rx1_o,
  input  wire                      x_rx1_ready_i,

  input  wire type_icon_tx_channel x_tx0_i
);

  //tx packet: addr_opx, addr, data, valid

  //RX side
  wire [1:0] x_rxx_idx_hit;
  assign x_rxx_idx_hit[0] = channel_port.tx.addr[0] == EU_IDX;
  assign x_rxx_idx_hit[1] = channel_port.tx.addr[1] == EU_IDX;

  //RX Valid check
  assign x_rx0_o.valid = channel_port[0].tx.valid;
  assign x_rx1_o.valid = channel_port[1].tx.valid;

  //RX data
  

  //Ready signals
  assign channel_port[0].rx.ready = 1'bz; //port 0 (TX) ready is disconnected
  assign channel_port[1].rx.ready = x_rxx_idx_hit[0] ? x_rx0_ready_i : 1'bz;
  assign channel_port[2].rx.ready = x_rxx_idx_hit[1] ? x_rx1_ready_i : 1'bz;

  //interconnect TX queue
  ram_queue #(
    .DATA_WIDTH($bits(type_icon_TXQentry)),
    .LOG2_SIZE(2)
  ) queue (
    .clk(clk),
    .reset_n(reset_n),
    .wvalid_i(),
    .wdata_i(),
    .rvalid_i(),
    .rready_i(),
    .rdata_o(),
    .full_o(),
    .empty_o()
  );

endmodule
