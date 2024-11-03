module eu_interconnect import exec_unit_dtypes::*; #(
  parameter NUM_CHANNELS = 2 //should be at least 2
) (
  inout wire  type_icon_tx_channel [NUM_CHANNELS-1:0] tx,
  inout wire  type_icon_rx_channel [NUM_CHANNELS-1:0] rx
);

  wire [NUM_CHANNELS-1:0] in_use;

endmodule
