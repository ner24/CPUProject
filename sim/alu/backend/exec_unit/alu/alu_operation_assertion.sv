import uvm_pkg::*;
`include "uvm_macros.svh"

module sva_alu_op import pkg_dtypes::*; #(
  parameter USE_PIPELINED_ALU = 0
) (
  input wire alu_clk,
  input wire alu_resetn,

  input  wire type_alu_channel_rx alu_rx_i,
  input  wire type_alu_channel_tx alu_tx_o,

  input  wire type_iqueue_opcode curr_instr_i,
  input  wire                   curr_instr_valid_i
);

  wire [DATA_WIDTH-1:0] in_a, in_b, out;
  //wire [$bits(curr_instr_i.specific_instr)-1:0] alu_cir;
  wire enum_instr_exec_unit alu_cir;
  assign in_a = alu_rx_i.op0_data;
  assign in_b = alu_rx_i.op1_data;
  assign out  = alu_tx_o.opd_data;
  assign alu_cir = enum_instr_exec_unit'(curr_instr_i.specific_instr);

  //check CIR value is valid (i.e. betwene h0 and hc)
  /*logic sva_prop_alu_cir;
  always_ff @(posedge alu_clk or negedge alu_resetn) begin: sva_prop_alu_cir_def
    if(~alu_resetn) begin
      sva_prop_alu_cir <= 1'b1;
    end else begin
      sva_prop_alu_cir <= alu_cir < 4'hd;
    end
  end

  //sva_alu_cir_range: assert property (@(posedge alu_clk) disable iff (~alu_resetn) alu_cir < 4'hd)
  sva_alu_cir_range: assert property (@(posedge alu_clk) sva_prop_alu_cir)
  else `uvm_error("SVA_ALU_OP", "CIR value out of range");*/

  logic [DATA_WIDTH-1:0] in_a_q,
                        in_a_q2,
                        in_a_sync,
                        in_b_q,
                        in_b_q2,
                        in_b_sync;
  enum_instr_exec_unit  alu_cir_q,
                        alu_cir_q2,
                        alu_cir_sync;
  generate if (USE_PIPELINED_ALU) begin
    always_ff @(posedge alu_clk) begin : ff_prop_input
      if (~alu_resetn) begin
        in_a_q    <= '0;
        in_a_q2   <= '0;
        in_a_sync <= '0;

        in_b_q    <= '0;
        in_b_q2   <= '0;
        in_b_sync <= '0;

        alu_cir_q    <= 'hf; //set to value out of range to not falsely trigger any asserts
        alu_cir_q2   <= 'hf;
        alu_cir_sync <= 'hf;
      end else begin
        in_a_q    <= in_a;
        in_a_q2   <= in_a_q;
        in_a_sync <= in_a_q2;

        in_b_q    <= in_b;
        in_b_q2   <= in_b_q;
        in_b_sync <= in_b_q2;

        alu_cir_q    <= alu_cir;
        alu_cir_q2   <= alu_cir_q;
        alu_cir_sync <= alu_cir_q2;
      end
    end
  end else begin
    always_comb begin
      in_a_q    <= '0;
      in_a_q2   <= '0;
      in_a_sync <= in_a;

      in_b_q    <= '0;
      in_b_q2   <= '0;
      in_b_sync <= in_b;

      alu_cir_q    <= '0;
      alu_cir_q2   <= '0;
      alu_cir_sync <= alu_cir;
    end
  end endgenerate

  //check ALU logic is valid (i.e. check operations are working correctly)
  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == MVN) & curr_instr_valid_i |-> out == ~in_a_sync)
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> NOT operation incorrect: %b -> %b", $time(), in_a_sync, out));

  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == AND) & curr_instr_valid_i |-> out == (in_b_sync & in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> AND operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));

  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == ORR) & curr_instr_valid_i |-> out == (in_b_sync | in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> OR operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));

  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == XOR) & curr_instr_valid_i |-> out == (in_b_sync ^ in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> XOR operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));

  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == NAND) & curr_instr_valid_i |-> out == ~(in_b_sync & in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> NAND operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));

  //TODO: add NOR and XNOR checks. Also MUL, DIV when they get added to design

  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == ADD) & curr_instr_valid_i |-> out == (in_b_sync + in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> ADD operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));
  
  assert property(@(posedge alu_clk) disable iff (~alu_resetn) (alu_cir_sync == SUB) & curr_instr_valid_i |-> out == (in_b_sync - in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> SUB operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));

endmodule


