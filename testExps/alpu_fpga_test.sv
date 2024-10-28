//`include "alu_parameters.sv"

module alpu_fpga_test #(
) (
  input wire clk,

  input  wire   [3:0] sw,
  input  wire   [3:0] btn,
  output wire   [3:0] led,
  output wire   [2:0] led6
);

  logic reset_n;
  initial begin
    reset_n = 1'b0;
    #1
    reset_n = 1'b1;
  end

  logic [7:0] input_buf;
  wire  [4:0] outp;
  logic [4:0] outp_buf;
  always_ff @( posedge clk ) begin : temp_reg
    if (~reset_n) begin
      //temp <= '0;
    end else begin
      input_buf[7:4] <= sw;
      input_buf[3:0] <= btn;

      outp_buf <= outp;
    end
  end
  assign led  = outp_buf[3:0];
  assign led6 = {2'b00, outp_buf[4]};

  alpu #(
    .REG_WIDTH(4),
    .USE_PIPELINED_ALPU(0)
  ) test (
    .clk(1'b0),
    .reset_n(1'b0),
    .instr_i(4'h4),
    .a_i(input_buf[7:4]),
    .b_i(input_buf[3:0]),
    .cin_i(1'b0),
    .out_o(outp[3:0]),
    .cout_o(outp[4])
  );

endmodule