`include "design_parameters.sv"

module alu import pkg_dtypes::*; #(
  parameter DATA_WIDTH = `WORD_WIDTH,
  parameter USE_PIPELINED_ALU = `ALU_USE_PIPELINED_ALU
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire type_alu_channel_rx alu_rx_i,
  output wire type_alu_channel_tx alu_tx_o,

  input  wire type_iqueue_opcode  curr_instr_i,
  input  wire                     curr_instr_valid_i,

  output wire                     ready_for_next_instr_o
);

  wire cout_o; //placeholder. This should eventually go back to flags reg through separate channel

  //since alu is stateless, opd_valid can just be high when instruction operands are ready
  assign alu_tx_o.opd_valid = curr_instr_valid_i & alu_rx_i.op0_valid & alu_rx_i.op1_valid;
  assign alu_tx_o.opd_addr  = alu_rx_i.opd_addr;
  
  assign ready_for_next_instr_o = (alu_rx_i.opd_store_success & alu_rx_i.op0_valid & alu_rx_i.op1_valid) | ~curr_instr_valid_i;

  // ----------------------
  // Instruction decoding
  // ----------------------
  wire enum_instr_exec_unit casted_specific_instr;
  assign casted_specific_instr = enum_instr_exec_unit'(curr_instr_i.specific_instr);
  logic [8:0] cir_decoded;
  always_comb begin: decode_instruction
    case(casted_specific_instr)
      //arithmetic and logic
      MVN : cir_decoded = 9'b 010001000 ;
      AND : cir_decoded = 9'b 001000100 ;
      ORR : cir_decoded = 9'b 001100100 ;
      XOR : cir_decoded = 9'b 000001000 ;
      ADD : cir_decoded = 9'b 001011000 ;
      SUB : cir_decoded = 9'b 101011000 ;
      NAND: cir_decoded = 9'b 001000110 ;
      NOR : cir_decoded = 9'b 001100110 ;
      XNOR: cir_decoded = 9'b 000001010 ;

      //barrel shift (WIP)
      LSR : cir_decoded = 9'b 000000001 ;
      LSL : cir_decoded = 9'b 000000011 ;
      //RRO : cir_decoded = 9'b 000000001 ;
      //LRO : cir_decoded = 9'b 000000001 ;

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
      .out_en(~cir_decoded[0]),
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
      .out_en(~cir_decoded[0]),
      .ctrl(cir_decoded[8:1]),
      .cin(1'b0),
      .cout(cout_o)
    );
  end endgenerate

  //placeholder barrel shifter
  logic [DATA_WIDTH-1:0] barrel_shift_out;
  always_comb begin
    case(cir_decoded)
      9'b 000000001: barrel_shift_out = alu_rx_i.op0_data >> alu_rx_i.op1_data;
      9'b 000000011: barrel_shift_out = alu_rx_i.op0_data << alu_rx_i.op1_data;

      default: barrel_shift_out = 'b0;
    endcase
  end

endmodule
