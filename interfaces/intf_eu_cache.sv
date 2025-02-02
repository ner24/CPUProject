interface intf_eu_cache import pkg_dtypes::*; #(
) (
  input logic clk
);

  logic                   reset_n;

  // ALPU interface
  // 2 buses: operands read, result write
  type_alu_channel_rx alu_rx_o;
  type_alu_channel_tx alu_tx_i;

  // Interconnect interface
  // 3 channels: operands write, operand read
  type_icon_tx_channel    icon_w0_i; //for op0
  type_icon_rx_channel icon_w0_rx_o;
  type_icon_tx_channel    icon_w1_i; //for op1
  type_icon_rx_channel icon_w1_rx_o;
  
  //not using type_icon_tx_channel since attributes go in different directions
  type_exec_unit_data  icon_rdata_o;
  type_exec_unit_addr  icon_raddr_i;
  logic                      icon_rvalid_i;
  logic                      icon_rsuccess_o;

  // Instruction reqeusts (from IQUEUE)
  type_iqueue_entry curr_instr_i;

  initial begin
    reset_n <= 1'b0;
  end

  /*modport DRIVER_SIDE (
    input clk,
    output reset_n,
    input rdata_o, rvalid_o, wack_o,
    output addr_i, wdata_i, ce_i, we_i
  );

  modport DUT_SIDE (
    input clk,
    input reset_n,
    output rdata_o, rvalid_o, wack_o,
    input addr_i, wdata_i, ce_i, we_i
  );

  modport VERIF_SIDE (
    input clk,
    input reset_n,
    input rdata_o, rvalid_o, wack_o,
    input addr_i, wdata_i, ce_i, we_i
  );*/
    
endinterface