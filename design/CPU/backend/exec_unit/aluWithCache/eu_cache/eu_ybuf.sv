module eu_ybuf import pkg_dtypes::*; #(
  parameter NUM_IDX_BITS = 2 //buffer sizes equal 2**NUM_IDX_BITS
) (
  input  wire clk,
  input  wire reset_n,

  input  wire type_alu_local_addr op0_req_addr_i,
  input  wire                     op0_req_addr_valid_i,
  input  wire type_alu_local_addr op1_req_addr_i,
  input  wire                     op1_req_addr_valid_i,

  output wire type_exec_unit_data op0_data_o,
  output wire                     op0_data_success_o,
  output wire type_exec_unit_data op1_data_o,
  output wire                     op1_data_success_o,

  input  wire type_alu_local_addr result_addr_i,
  input  wire type_exec_unit_data result_data_i,
  input  wire                     result_valid_i,
  //outputs whether result was stored successfully
  output wire                     result_success_o
);

  typedef struct packed {
    logic n_hbr;
    type_exec_unit_data data;
  } type_ybuf_entry;

  //if no requests, send to sleep
  wire enable_ybufs;
  assign enable_ybufs = op0_req_addr_valid_i | op1_req_addr_valid_i | result_valid_i;

  // ------------------------------
  // ys buffer
  // ------------------------------
  wire result_store_slot_available;

  logic ys_valid;
  typedef struct packed {
    type_alu_local_addr addr;
    type_exec_unit_data data;
  } type_ys_entry;
  type_ys_entry ys_buffer;
  always_ff @(posedge clk) begin: ff_ys_buffer
    if(~reset_n) begin
      ys_buffer = 'b0;
      ys_valid = 1'b0;
    end else begin
      //result_store_slot_available is high when hbr check passes
      //for requested cache address
      if (result_valid_i & result_store_slot_available) begin
        ys_buffer.addr = result_addr_i;
        ys_buffer.data = result_data_i;
        ys_valid = 1'b1;
      end else if (enable_ybufs) begin
        //"freeze" ys buffer when disabled
        ys_valid = 1'b0;
      end
    end
  end

  wire ys_hit_op0, ys_hit_op1;
  assign ys_hit_op0 = op0_req_addr_valid_i & (op0_req_addr_i == ys_buffer.addr);
  assign ys_hit_op1 = op1_req_addr_valid_i & (op1_req_addr_i == ys_buffer.addr);

  // ----------------------------------
  // y buffer r and w mode interfaces
  // ----------------------------------

  wire  type_alu_local_addr r_addra;
  wire  type_alu_local_addr r_addrb;
  wire  type_ybuf_entry r_rdataa;
  wire  type_ybuf_entry r_rdatab;
  wire            r_fetch_success;
  //logic           r_hita;

  wire            r_n_hbr;

  wire type_alu_local_addr w_addra;
  wire type_alu_local_addr w_addrb;
  wire type_ybuf_entry w_wdataa;
  wire type_ybuf_entry w_rdatab;
  wire            w_fetch_success;
  
  assign r_addra = result_addr_i;
  assign r_addrb = op0_req_addr_i;
  
  assign w_addra = ys_buffer.addr;
  assign w_addrb = op1_req_addr_i;
  assign w_wdataa.data = ys_buffer.data;
  assign w_wdataa.n_hbr = 1'b1;

  assign r_n_hbr = r_rdataa.n_hbr;

  assign op0_data_o = ys_hit_op0 ? ys_buffer.data : r_rdatab.data;
  assign op0_data_success_o = ys_hit_op0 | (r_fetch_success & r_rdatab.n_hbr);
  assign op1_data_o = ys_hit_op0 ? ys_buffer.data : w_rdatab.data;
  assign op1_data_success_o = ys_hit_op0 | (w_fetch_success & w_rdatab.n_hbr);

  assign result_store_slot_available = ~r_n_hbr;
  assign result_success_o = result_valid_i & result_store_slot_available;

  // ------------------------------
  // multiplex r and w wires
  // ------------------------------

  //used for swapping r and w markers on the buffers
  logic y_sw;
  //logic y_sw_0;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      y_sw = 1'b0;
    end else begin
      if (enable_ybufs) begin
        y_sw = ~y_sw;
      end
    end
  end
  always_comb begin
    //y_sw[1] = ~y_sw[0];
    //y_sw_0 = y_sw[0];
  end

  wire type_alu_local_addr combined_addra [1:0];
  wire type_alu_local_addr combined_addrb [1:0];
  wire type_ybuf_entry combined_rdataa [1:0];
  wire type_ybuf_entry combined_rdatab [1:0];
  wire combined_fetch_success [1:0];
  //wire combined_rhita [1:0];

  assign combined_addra[0] = y_sw ? w_addra : r_addra;
  assign combined_addra[1] = y_sw ? r_addra : w_addra;
  assign combined_addrb[0] = y_sw ? w_addrb : r_addrb;
  assign combined_addrb[1] = y_sw ? r_addrb : w_addrb;

  assign r_rdataa = y_sw ? combined_rdataa[1] : combined_rdataa[0];
  assign r_rdatab = y_sw ? combined_rdatab[1] : combined_rdatab[0];
  assign w_rdatab = y_sw ? combined_rdatab[0] : combined_rdatab[1];

  assign r_fetch_success = y_sw ? combined_fetch_success[1] : combined_fetch_success[0];
  assign w_fetch_success = y_sw ? combined_fetch_success[0] : combined_fetch_success[1];

  // -----------------------
  // y buffers
  // -----------------------

  generate for(genvar y_idx = 0; y_idx < 2; y_idx++) begin: g_ybuf
    wire we;
    assign we = ys_valid & (y_idx ? ~y_sw : y_sw);

    cache_DP #(
      .IDX_BITS(NUM_IDX_BITS),
      .DATA_WIDTH($bits(type_ybuf_entry)),
      .ADDR_WIDTH($bits(type_alu_local_addr))
    ) ram (
      .clk(clk),
      .reset_n(reset_n),

      .addra_i(combined_addra[y_idx]),
      .addrb_i(combined_addrb[y_idx]),

      .wdata_i(w_wdataa),

      .cea_i(enable_ybufs),
      .ceb_i(enable_ybufs),
      .we_i(we), //means when sw is 0, y0 is r and y1 is w

      .rdataa_o(combined_rdataa[y_idx]),
      .rdatab_o(combined_rdatab[y_idx]),
      //.rhita_o(combined_rhita[y_idx]),
      .rhita_o(),
      .rhitb_o(combined_fetch_success[y_idx])
    );
  end endgenerate

endmodule
