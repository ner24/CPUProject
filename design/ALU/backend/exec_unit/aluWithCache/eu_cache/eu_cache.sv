`include "design_parameters.sv"

module alpu_cache import pkg_dtypes::*; #(
  //IDX used to work out if operand is local or foreign
  parameter ALPU_IDX = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  // ALPU interface
  // 2 buses: operands read, result write
  output wire type_alu_channel_rx alu_rx,
  input  wire type_alu_channel_tx alu_tx,

  // Interconnect interface
  // 3 channels: operands write, operand read
  input  wire type_icon_tx_channel    icon_w0, //for op0
  output wire type_icon_rx_channel icon_w0_rx,
  input  wire type_icon_tx_channel    icon_w1, //for op1
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
  // --------------------------
  // ALU interface
  // --------------------------
  //output register for storing one of the already prepared operands
  //e.g. if op1 fetch gets delayed but op0 does not, keep op0 in this register
  //then when op1 is finally fetched, pass it to alu directly and op0 from register

  wire rx0_alu_req_channel;

  // --------------------------
  // X buffers
  // --------------------------

  generate for (genvar g_opx = 0; g_opx < 2; g_opx++) begin: g_rx
    eu_xbuf #(
      .NUM_IDX_BITS(`EU_CACHE_XBUF_NUM_IDX_BITS)
    ) xbuf (
      .clk(clk),
      .reset_n(reset_n),

      //interconnect interface
      .in_pkt(g_opx ? icon_w1 : icon_w0),
      .in_success(g_opx ? icon_w1_rx.success : icon_w0_rx.success),

      //ALU interface
      .alu_req_addr(),
      .alu_req_valid(),
      .alu_resp_data(),
      .out_success()
    );
  end endgenerate


endmodule
