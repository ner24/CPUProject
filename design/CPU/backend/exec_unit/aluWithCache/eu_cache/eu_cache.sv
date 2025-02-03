`include "design_parameters.sv"

module eu_cache import pkg_dtypes::*; #(
  //IDX used to work out if operand is local or foreign
  parameter EU_IDX = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  // ALU interface
  // 2 buses: operands read, result write
  output wire type_alu_channel_rx alu_rx_o,
  input  wire type_alu_channel_tx alu_tx_i,

  // Interconnect interface
  // 3 channels: operands write, operand read
  input  wire type_icon_tx_channel    icon_w0_i, //for op0
  output wire type_icon_rx_channel icon_w0_rx_o,
  input  wire type_icon_tx_channel    icon_w1_i, //for op1
  output wire type_icon_rx_channel icon_w1_rx_o,
  
  //not using type_icon_tx_channel since attributes go in different directions
  output wire type_exec_unit_data  icon_rdata_o,
  input  wire type_exec_unit_addr  icon_raddr_i,
  input  wire                      icon_rvalid_i,
  output wire                      icon_rsuccess_o,

  // Instruction reqeusts (from IQUEUE)
  input  wire type_iqueue_entry curr_instr_i
);

  wire curr_instr_op0_isreg;
  wire curr_instr_op0_isforeign;
  wire curr_instr_op1_isreg;
  wire curr_instr_op1_isforeign;
  wire alu_res_opd_isforeign;
  assign curr_instr_op0_isreg     = curr_instr_i.op0m == REG;
  assign curr_instr_op0_isforeign = curr_instr_op0_isreg ? curr_instr_i.op0.as_addr.euidx == EU_IDX : 1'b0;
  assign curr_instr_op1_isreg     = curr_instr_i.op1m == REG;
  assign curr_instr_op1_isforeign = curr_instr_op1_isreg ? curr_instr_i.op1.as_addr.euidx == EU_IDX : 1'b0;
  assign alu_res_opd_isforeign    = alu_tx_i.opd_addr.euidx == EU_IDX;

  // --------------------------
  // ALU interface
  // --------------------------
  //output register for storing one of the already prepared operands
  //e.g. if op1 fetch gets delayed but op0 does not, keep op0 in this register
  //then when op1 is finally fetched, pass it to alu directly and op0 from register

  wire rx0_alu_req_channel;

  // --------------------------
  // Operand channels
  // --------------------------
  
  //foreign op0
  wire type_exec_unit_data fop0_data;
  wire                     fop0_success;

  //foreign op1
  wire type_exec_unit_data fop1_data;
  wire                     fop1_success;

  //local op0
  wire type_exec_unit_data op0_data;
  wire                     op0_success;

  //local op1
  wire type_exec_unit_data op1_data;
  wire                     op1_success;

  //opd
  wire type_exec_unit_data opd_data;
  wire                     opd_valid;

  wire                     opd_foreign_success;
  wire                     opd_local_success;
  wire                     opd_stored_success;
  assign opd_stored_success = opd_foreign_success | opd_local_success;

  // --------------------------
  // Prepared op reg
  // --------------------------

  eu_prepop #(
    .EU_IDX(EU_IDX)
  ) prepop (
    //foreign op0
    .fop0_data_i(fop0_data),
    .fop0_success_i(fop0_success),

    //foreign op1
    .fop1_data_i(fop1_data),
    .fop1_success_i(fop1_success),

    //local op0
    .op0_data_i(op0_data),
    .op0_success_i(op0_success),

    //local op1
    .op1_data_i(op1_data),
    .op1_success_i(op1_success),

    //iqueue requested addresses
    .current_instr_i(ireq_curr_instr_i),
    .op0_isreg_i(curr_instr_op0_isreg),
    .op0_isforeign_i(curr_instr_op0_isforeign),
    .op1_isreg_i(curr_instr_op1_isreg),
    .op1_isforeign_i(curr_instr_op1_isforeign),

    //output operands
    .op0_o(alu_rx_o.op0_data),
    .op0_success_o(alu_rx_o.op0_valid),
    .op1_o(alu_rx_o.op1_data),
    .op1_success_o(alu_rx_o.op1_valid)
  );

  // --------------------------
  // Y buffers
  // --------------------------
  wire type_alu_local_addr op0_local_addr;
  wire type_alu_local_addr op1_local_addr;
  wire type_alu_local_addr opd_local_addr;
  assign op0_local_addr.uid = curr_instr_i.op0.as_addr.uid;
  assign op0_local_addr.spec = curr_instr_i.op0.as_addr.spec;
  assign op1_local_addr.uid = curr_instr_i.op1.as_addr.uid;
  assign op1_local_addr.spec = curr_instr_i.op1.as_addr.spec;
  assign opd_local_addr.uid = alu_tx_i.opd.addr.uid;
  assign opd_local_addr.spec = alu_tx_i.opd.addr.spec;

  eu_ybuf #(
    .NUM_IDX_BITS(`EU_CACHE_YBUF_NUM_IDX_BITS)
  ) ybufs (
    .clk(clk),
    .reset_n(reset_n),

    .op0_req_addr_i(op0_local_addr),
    .op0_req_addr_valid_i(~curr_instr_op0_isforeign),
    .op1_req_addr_i(op1_local_addr),
    .op1_req_addr_valid_i(~curr_instr_op1_isforeign),

    .op0_data_o(op0_data),
    .op0_data_success_o(op0_success),
    .op1_data_o(op1_data),
    .op1_data_success_o(op1_success),

    .result_addr_i(opd_local_addr),
    .result_data_i(alu_tx_i.data),
    .result_valid_i(~alu_res_opd_isforeign & alu_tx_i.opd_valid),
    .result_success_o(opd_local_success)
  );

  // --------------------------
  // X buffers
  // --------------------------

  generate for (genvar g_opx = 0; g_opx < 2; g_opx++) begin: g_rx
    eu_xbuf #(
      .NUM_IDX_BITS(`EU_CACHE_XBUF_NUM_IDX_BITS)
    ) xbuf (
      .clk(clk),
      .reset_n(reset_n),

      //from ICON
      .in_addr_i(g_opx ? icon_w1_i.addr : icon_w0_i.addr),
      .in_valid_i(g_opx ? icon_w1_i.valid : icon_w0_i.valid),
      .in_data_i(g_opx ? icon_w1_i.data : icon_w0_i.data),
      .in_success_o(g_opx ? icon_w1_rx_o.success : icon_w0_rx_o.success),

      //to ALU (so req will be from current instr)
      .req_addr_i(g_opx ? curr_instr_i.op1.as_addr : curr_instr_i.op0.as_addr),
      .req_valid_i(g_opx ? curr_instr_op1_isforeign : curr_instr_op0_isforeign),
      .resp_data_o(g_opx ? fop1_data : fop0_data),
      .resp_success_o(g_opx ? fop1_success : fop0_success)
    );
  end endgenerate

  eu_xbuf #(
    .NUM_IDX_BITS(`EU_CACHE_XBUF_NUM_IDX_BITS)
  ) tx_xbuf (
    .clk(clk),
    .reset_n(reset_n),

    //from ALU
    .in_addr_i(alu_tx_i.opd_addr),
    .in_valid_i(alu_res_opd_isforeign & alu_tx_i.opd_valid),
    .in_data_i(alu_tx_i.opd_data),
    .in_success_o(opd_foreign_success),

    //to ICON
    .req_addr_i(icon_raddr_i),
    .req_valid_i(icon_rvalid_i),
    .resp_data_o(icon_rdata_o),
    .resp_success_o(icon_rsuccess_o)
  );


endmodule
