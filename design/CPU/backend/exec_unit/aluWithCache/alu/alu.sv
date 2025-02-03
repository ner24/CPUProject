`include "design_parameters.sv"

module alu import pkg_dtypes::*; #(
  parameter DATA_WIDTH = `WORD_WIDTH,
  parameter USE_PIPELINED_ALU = `ALU_USE_PIPELINED_ALU
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire type_alu_channel_rx alu_rx_i,
  output wire type_alu_channel_tx alu_tx_o,

  input  wire type_iqueue_entry curr_instr_i,
  input  wire                   curr_instr_valid_i
);

  wire cout_o; //placeholder. This should eventually go back to flags reg through separate channel

  assign alu_tx.opd_valid = curr_instr_valid_i & alu_rx.op0_valid & alu_rx.op1_valid;
  assign alu_tx.opd_addr  = alu_rx_i.opd_addr;

  // ----------------------
  // Instruction decoding
  // ----------------------
  logic [8:0] cir_decoded;
  always_comb begin: decode_instruction
    case(curr_instr_i.specific_instr)
      //arithmetic and logic
      4'h 0: cir_decoded = 9'b 010001000 ; //NOT
      4'h 1: cir_decoded = 9'b 001000100 ; //AND
      4'h 2: cir_decoded = 9'b 001100100 ; //OR
      4'h 3: cir_decoded = 9'b 000001000 ; //XOR
      4'h 4: cir_decoded = 9'b 001011000 ; //ADD
      4'h 5: cir_decoded = 9'b 101011000 ; //SUB
      4'h 6: cir_decoded = 9'b 001000110 ; //NAND
      4'h 7: cir_decoded = 9'b 001100110 ; //NOR
      4'h 8: cir_decoded = 9'b 000001010 ; //XNOR

      //barrel shift (WIP)
      4'h 9: cir_decoded = 9'b 000000001 ; //RSH
      4'h a: cir_decoded = 9'b 000000001 ; //LSH
      4'h b: cir_decoded = 9'b 000000001 ; //RRO
      4'h c: cir_decoded = 9'b 000000001 ; //LRO

      default: cir_decoded = 9'b 000000000 ; //should never hit
    endcase
  end

  generate if (USE_PIPELINED_ALU) begin: g_alu_comb_piped
    alu_comb_piped #(
      .DATA_WIDTH(DATA_WIDTH)
    ) u_alu_comb (
      .clk(clk),
      .reset_n(reset_n),
      .pipe_active(1'b1),

      .a(alu_rx_i.op0_data),
      .b(alu_rx_i.op1_data),
      .out(alu_tx_o.opd_data),
      .ctrl(cir_decoded[8:1]),
      .cin(1'b0),
      .cout(cout_o)
    );
  end else begin: g_alu_comb_n_piped
    alu_comb #(
      .DATA_WIDTH(DATA_WIDTH)
    ) u_alu_comb (
      .a(alu_rx_i.op0_data),
      .b(alu_rx_i.op1_data),
      .out(alu_tx_o.opd_data),
      .ctrl(cir_decoded[8:1]),
      .cin(1'b0),
      .cout(cout_o)
    );
  end endgenerate

endmodule
