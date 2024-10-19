interface intf_alpu_cache #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) (
  input wire clk
);

  logic                   reset_n;

  logic  [ADDR_WIDTH-1:0] addr_i;
  logic  [DATA_WIDTH-1:0] wdata_i;

  logic                   ce_i;
  logic                   we_i;

  logic  [DATA_WIDTH-1:0] rdata_o;
  logic                   rvalid_o;
  logic                   wack_o;

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