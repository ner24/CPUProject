interface alu_dut_intf #(
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
    
endinterface