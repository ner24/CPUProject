interface intf_alpu #(
  parameter REG_WIDTH = 4
) (
  input wire clk
);

  logic                  reset_n;

  logic[REG_WIDTH-1:0]   a_i;
  logic[REG_WIDTH-1:0]   b_i;
  logic[3:0]             instr_i;
  logic                  cin_i;

  logic[REG_WIDTH-1:0]   out_o;
  logic                  cout_o;

  initial begin
    reset_n <= 1'b0;
  end

  /*modport DRIVER_SIDE (
    input clk,
    output reset_n,
    input out_o, cout_o,
    output a_i, b_i, instr_i, cin_i
  );

  modport DUT_SIDE (
    input clk,
    input reset_n,
    input a_i, b_i, instr_i, cin_i,
    output out_o, cout_o
  );

  modport VERIF_SIDE (
    input clk,
    input reset_n,
    input a_i, b_i, instr_i, cin_i, out_o, cout_o
  );*/
    
endinterface