module back_iconch_interface import pkg_dtypes::*; #(
  parameter EU_IDX = 0
) (
  //icon side
  //NOTE: req_valid assumes icon controller resolves
  //resource collisions and arbitration internally (within icon controller)
  input  wire type_icon_tx_channel_chside icon_tx_i,
  output wire type_icon_rx_channel_chside icon_rx_o,

  //eu rx side
  output wire type_icon_tx_channel eu_rx_o,
  input  wire type_icon_rx_channel eu_rx_resp_i,
  
  //eu tx side
  /*input  wire type_exec_unit_data  eu_tx_resp_data_i,
  output wire type_exec_unit_addr  eu_tx_addr_o,
  output wire                      eu_tx_valid_o,
  input  wire                      eu_tx_resp_data_valid_i,*/
  output type_icon_tx_rx_channel   eu_tx_o,
  input  type_icon_tx_tx_channel   eu_tx_resp_i,

  //extra control
  //force_disable_tx primarily used to make sure the intf for opx1
  //is not also handling the same tx request as intf for opx0
  input  wire                      force_disable_tx
);

  // ---------------
  // enable signals
  // ---------------

  wire eu_tx_enable;
  wire eu_rx_enable;

  //tx = 1, rx = 0
  wire tx_euidx_match;
  assign tx_euidx_match = icon_tx_i.src_addr.euidx == EU_IDX;

  assign eu_tx_enable = icon_tx_i.req_tx_valid & tx_euidx_match & (~force_disable_tx);
  assign eu_rx_enable = icon_tx_i.req_valid    & icon_tx_i.data_valid_tx;

  // ---------------
  // output eu rx
  // ---------------

  assign eu_rx_o.valid = eu_rx_enable;
  assign eu_rx_o.data  = eu_rx_enable ? icon_tx_i.data_tx  : 'b0;
  assign eu_rx_o.addr  = eu_rx_enable ? icon_tx_i.src_addr : 'b0;

  // ---------------
  // output eu tx
  // ---------------

  assign eu_tx_o.src_addr_tx  = eu_tx_enable ? icon_tx_i.src_addr : 'b0;
  assign eu_tx_o.valid_tx     = eu_tx_enable;

  // ------------------------
  // output to icon channel
  // ------------------------

  assign icon_rx_o.data_rx       = eu_tx_enable ? eu_tx_resp_i.data_tx    : 'b0;
  assign icon_rx_o.data_valid_rx = eu_tx_enable ? eu_tx_resp_i.success_tx : 'b0;

  assign icon_rx_o.success = eu_rx_enable & eu_rx_resp_i.success;

endmodule
