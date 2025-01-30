
module alpu_cache import pkg_dtypes::*; #(
  //IDX used to work out if operand is local or foreign
  parameter ALPU_IDX = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  // ALPU interface
  // 2 buses: operands read, result write
  output wire type_alpu_channel_rx alpu_rx,
  input  wire type_alpu_channel_tx alpu_tx,

  // Interconnect interface
  // 3 channels: operands write, operand read
  input  wire type_icon_tx_channel    icon_w0, //for op0
  output wire type_icon_rx_channel icon_w0_rx,
  input  wire type_icon_tx_channel    icon_w1, //for op
  output wire type_icon_rx_channel icon_w1_rx,
  
  //not using type_icon_tx_channel since attributes go in different directions
  output wire type_exec_unit_data  icon_r0data,
  input  wire type_exec_unit_addr  icon_r0addr,
  output wire                      icon_r0valid,
  input  wire                      icon_r0ready,

  // Instruction reqeusts (from IQUEUE)
  // 2 buses: operands read request, foreign data prefetch (WIP)
  // no need for valid on write. Instructions always write to some cache
  // if address is invalid, then ireq contained immediate for operand
  input  wire type_iqueue_entry ireq_curr_instr
);




endmodule
