import uvm_pkg::*;
`include "uvm_macros.svh"

module sva_alu_op #(
  parameter REG_WIDTH = 16,
  parameter USE_PIPELINED_ALU = 1
) (
  input wire alu_clk,
  input wire alu_resetn,

  input wire            [3:0] alu_cir,
  input wire  [REG_WIDTH-1:0] in_a,
  input wire  [REG_WIDTH-1:0] in_b,
  input wire  [REG_WIDTH-1:0] out
);
  //check CIR value is valid (i.e. betwene h0 and hc)
  logic sva_prop_alu_cir;
  always_ff @(posedge alu_clk or negedge alu_resetn) begin: sva_prop_alu_cir_def
    if(~alu_resetn) begin
      sva_prop_alu_cir <= 1'b1;
    end else begin
      sva_prop_alu_cir <= alu_cir < 4'hd;
    end
  end

  //sva_alu_cir_range: assert property (@(posedge alu_clk) disable iff (~alu_resetn) alu_cir < 4'hd)
  sva_alu_cir_range: assert property (@(posedge alu_clk) sva_prop_alu_cir)
  else `uvm_error("SVA_ALU_OP", "CIR value out of range");

  logic [REG_WIDTH-1:0] in_a_q,
                        in_a_q2,
                        in_a_sync,
                        in_b_q,
                        in_b_q2,
                        in_b_sync;
  logic           [3:0] alu_cir_q,
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
  generate for(genvar i = 0; i < REG_WIDTH; i = i + 1) begin : g_alu_formal_bitwise
    assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h0 |-> out[i] == ~in_a_sync[i])
    else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> NOT operation at bit idx %0d incorrect: %b -> %b", $time(), i, in_a_sync, out));

    assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h1 |-> out[i] == (in_b_sync[i] & in_a_sync[i]))
    else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> AND operation at bit idx %0d incorrect: %b %b -> %b", $time(), i, in_a_sync, in_b_sync, out));

    assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h2 |-> out[i] == (in_b_sync[i] | in_a_sync[i]))
    else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> OR operation at bit idx %0d incorrect: %b %b -> %b", $time(), i, in_a_sync, in_b_sync, out));

    assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h3 |-> out[i] == (in_b_sync[i] ^ in_a_sync[i]))
    else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> XOR operation at bit idx %0d incorrect: %b %b -> %b", $time(), i, in_a_sync, in_b_sync, out));

    assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h6 |-> out[i] == ~(in_b_sync[i] & in_a_sync[i]))
    else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> NAND operation at bit idx %0d incorrect: %b %b -> %b", $time(), i, in_a_sync, in_b_sync, out));

    //add nor and xnor checks
  end endgenerate

  assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h4 |-> out == (in_b_sync + in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> ADD operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));
  
  assert property(@(posedge alu_clk) disable iff (~alu_resetn) alu_cir_sync == 4'h5 |-> out == (in_b_sync - in_a_sync))
  else `uvm_error("SVA_ALU_OP", $sformatf("%0d -> SUB operation incorrect: %b %b -> %b", $time(), in_a_sync, in_b_sync, out));

endmodule


