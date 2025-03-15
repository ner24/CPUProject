module eu_prepop import pkg_dtypes::*; #(
  parameter EU_IDX = 0
) (
  input wire clk,
  input wire reset_n,

  //foreign op0
  //input  wire type_exec_unit_addr fop0_addr_i, //where f is for foreign
  input  wire type_exec_unit_data fop0_data_i,
  input  wire                     fop0_success_i,

  //foreign op1
  //input  wire type_exec_unit_addr fop1_addr_i,
  input  wire type_exec_unit_data fop1_data_i,
  input  wire                     fop1_success_i,

  //local op0
  //input  wire type_alu_local_addr op0_addr_i,
  input  wire type_exec_unit_data op0_data_i,
  input  wire                     op0_success_i,

  //local op1
  //input  wire type_alu_local_addr op1_addr_i,
  input  wire type_exec_unit_data op1_data_i,
  input  wire                     op1_success_i,

  //iqueue requested addresses
  input  wire type_iqueue_entry   current_instr_i,
  input  wire                     op0_isreg_i, //if 1, then is reg, else immedate
  input  wire                     op0_isforeign_i,
  input  wire                     op1_isreg_i,
  input  wire                     op1_isforeign_i,

  //output operands
  output      type_exec_unit_data op0_o,
  output logic                    op0_success_o,
  output      type_exec_unit_data op1_o,
  output logic                    op1_success_o
);

  typedef struct packed {
    logic               valid;
    logic               opx;
    //type_exec_unit_addr addr;
    type_exec_unit_data data;
  } type_prepop_entry;

  logic using_reg_data; //if 1, then one of the outputted operands is from the register
  always_comb begin
    using_reg_data = 1'b0;
    op0_success_o = 1'b0;
    op1_success_o = 1'b0;

    if (op0_isreg_i) begin
      //type_exec_unit_addr op0_req_addr;
      //op0_req_addr = current_instr_i.op0.as_addr;
      if (~register.opx & register.valid) begin
        op0_o = register.data;
        op0_success_o = 1'b1;
        using_reg_data = 1'b1;
      end else begin
        if (op0_isforeign_i) begin
          op0_o = fop0_data_i;
          op0_success_o = fop0_success_i;
        end else begin
          op0_o = op0_data_i;
          op0_success_o = op0_success_i;
        end
      end
    end else begin
      op0_o = current_instr_i.op0.as_imm.data;
      op0_success_o = 1'b1;
    end

    if (op1_isreg_i) begin
      //type_exec_unit_addr op1_req_addr;
      //op1_req_addr = current_instr_i.op1.as_addr;
      if (register.opx & register.valid) begin
        op1_o = register.data;
        op1_success_o = 1'b1;
        using_reg_data = 1'b1;
      end else begin
        if (op1_isforeign_i) begin
          op1_o = fop1_data_i;
          op1_success_o = fop1_success_i;
        end else begin
          op1_o = op1_data_i;
          op1_success_o = op1_success_i;
        end
      end
    end else begin
      op1_o = current_instr_i.op1.as_imm.data;
      op1_success_o = 1'b1;
    end
  end
  
  //only enable when only one operand was found for power saving
  logic write_enable;
  always_comb begin
    write_enable = (op0_isreg_i & (op0_success_i | fop0_success_i))
                  ^ (op1_isreg_i & (op1_success_i | fop1_success_i));
  end

  type_prepop_entry register;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      register = 'b0;
    end else begin

      if (~register.valid & write_enable) begin
        if (op0_success_i & op0_isreg_i & ~op0_isforeign_i) begin
          register.valid = 1'b1;
          register.opx = 1'b0;
          //register.addr.eu_idx = EU_IDX;
          //register.addr.uid = op0_addr_i.uid;
          //register.addr.spec = op0_addr_i.spec;
          register.data = op0_data_i;
        end else if (fop0_success_i & op0_isforeign_i) begin
          register.valid = 1'b1;
          register.opx = 1'b0;
          //register.addr = fop0_addr_i.addr;
          register.data = fop0_data_i;
        end else if (op1_success_i & op1_isreg_i & ~op1_isforeign_i) begin
          register.valid = 1'b1;
          register.opx = 1'b1;
          //register.addr.eu_idx = EU_IDX;
          //register.addr.uid = op1_addr_i.uid;
          //register.addr.spec = op1_addr_i.spec;
          register.data = op1_data_i;
        end else if (fop1_success_i & op1_isreg_i & op1_isforeign_i) begin
          register.valid = 1'b1;
          register.opx = 1'b1;
          //register.addr = fop1_addr_i.addr;
          register.data = fop1_data_i;
        end
      end

      //valid reset should be after valid set. E.g. in operations where there is only one
      //reg operand, the code above will set valid high but it should go back low the same cycle
      if ((op0_success_o & op1_success_i) | (op0_success_i & op1_success_o)) begin
        register.valid = 1'b0; //set valid to 0 next cycle, i.e. reset reg for next instr
      end

    end
  end

endmodule
