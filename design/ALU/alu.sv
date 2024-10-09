module alu #(
  parameter REG_WIDTH = 8,
  parameter USE_PIPELINED_ALU = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  logic            [3:0] instr_i,
  input  wire   [REG_WIDTH-1:0] a_i,
  input  wire   [REG_WIDTH-1:0] b_i,
  input  wire                   cin_i,
  output wire   [REG_WIDTH-1:0] acc_o,
  output wire                   cout_o
);

  //logic [REG_WIDTH-1:0] reg_acc;
  wire  [REG_WIDTH-1:0] out_wire;
  //assign acc_o = reg_acc;
  assign acc_o = out_wire;
  /*always_comb begin: rst
    if(~reset_n) begin
      reg_acc <= '0;
    end else begin
      reg_acc <= out_wire;
    end
  end*/

  // ----------------------
  // Instruction decoding
  // ----------------------
  logic [8:0] cir_decoded;
  always_comb begin: decode_instruction
    case(instr_i)
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
      .REG_WIDTH(REG_WIDTH)
    ) u_alu_comb (
      .clk(clk),
      .reset_n(reset_n),
      .pipe_active(1'b1),

      .a(a_i),
      .b(b_i),
      .out(out_wire),
      .ctrl(cir_decoded[8:1]),
      .cin(cin_i),
      .cout(cout_o)
    );
  end else begin: g_alu_comb_n_piped
    alu_comb #(
      .REG_WIDTH(REG_WIDTH)
    ) u_alu_comb (
      .a(a_i),
      .b(b_i),
      .out(out_wire),
      .ctrl(cir_decoded[8:1]),
      .cin(cin_i),
      .cout(cout_o)
    );
  end endgenerate

endmodule
