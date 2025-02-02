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
    logic hbr;
    type_exec_unit_data data;
  } type_ybuf_entry;

  //if no requests, send to sleep
  wire enable_ybufs;
  assign enable_ybufs = op0_req_addr_valid_i | op1_req_addr_valid_i;

  // ------------------------------
  // ys buffer
  // ------------------------------

  typedef struct packed {
    type_alu_local_addr addr;
    type_exec_unit_data data;
  } type_ys_entry;
  type_ys_entry ys_buffer;
  always_ff @(posedge clk) begin: ff_ys_buffer
    if(~reset_n) begin
      ys_buffer = 'b0;
    end else begin
      if (result_valid_i) begin
        ys_buffer.addr = result_addr_i;
        ys_buffer.data = result_data_i;
      end
    end
  end

  // ----------------------------------
  // y buffer r and w mode interfaces
  // ----------------------------------

  wire  type_alu_local_addr r_addra;
  wire  type_alu_local_addr r_addrb;
  type_ybuf_entry r_rdataa;
  type_ybuf_entry r_rdatab;
  logic           r_fetch_success;
  //logic           r_hita;

  wire            r_hbr;

  wire type_alu_local_addr w_addra;
  wire type_alu_local_addr w_addrb;
  wire type_ybuf_entry w_wdataa;
  type_ybuf_entry w_rdatab;
  logic           w_fetch_success;
  
  assign r_addra = result_addr_i;
  assign r_addrb = op0_req_addr_i;
  
  assign w_addra = ys_buffer.addr;
  assign w_addrb = op1_req_addr_i;
  assign w_wdataa = ys_buffer.data;

  assign r_hbr = r_rdataa.hbr;

  assign op0_data_o = r_rdatab.data;
  assign op0_data_success_o = ~r_rdatab.hbr;
  assign op1_data_o = w_wdatab.data;
  assign op1_data_success_o = ~w_rdatab.hbr;

  assign result_success_o = r_hbr;

  // ------------------------------
  // multiplex r and w wires
  // ------------------------------

  //used for swapping r and w markers on the buffers
  logic y_sw [1:0];
  logic y_sw_0;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      y_sw[0] = 1'b0;
    end else begin
      if (enable_ybufs) begin
        y_sw[0] = ~y_sw[0];
      end
    end
  end
  always_comb begin
    y_sw[1] = ~y_sw[0];
    y_sw_0 = y_sw[0];
  end

  type_alu_local_addr combined_addra [1:0];
  type_alu_local_addr combined_addrb [1:0];
  wire type_ybuf_entry combined_rdataa [1:0];
  wire type_ybuf_entry combined_rdatab [1:0];
  wire combined_fetch_success [1:0];
  wire combined_rhita [1:0];

  always_comb begin //when sw is 0, y0 is r and y1 is w
    combined_addra[y_sw_0] = r_addra;
    combined_addrb[y_sw_0] = r_addrb;
    combined_addra[~y_sw_0] = w_addra;
    combined_addrb[~y_sw_0] = w_addrb;

    r_rdataa = combined_rdataa[y_sw_0];
    r_rdatab = combined_rdatab[y_sw_0];
    w_rdatab = combined_rdatab[~y_sw_0];

    r_fetch_success = combined_fetch_success[y_sw_0];
    w_fetch_success = combined_fetch_success[~y_sw_0];

    //r_hita = combined_rhita[y_sw_0];
  end

  // -----------------------
  // y buffers
  // -----------------------

  generate for(genvar y_idx = 0; y_idx < 2; y_idx++) begin
    cache_DP #(
      .IDX_BITS(NUM_IDX_BITS),
      .DATA_WIDTH($bits(type_ybuf_entry)),
      .ADDR_WIDTH($bits(type_alu_local_addr))
    ) ram (
      .clk(clk),
      .reset_n(reset_n),

      .addra_i(combined_addra[i]),
      .addrb_i(combined_addrb[i]),

      .wdata_i(w_wdataa),

      .cea_i(enable_ybufs),
      .ceb_i(enable_ybufs),
      .we_i(y_sw[i]), //means when sw is 0, y0 is r and y1 is w

      .rdataa_o(combined_rdataa[i]),
      .rdatab_o(combined_rdatab[i]),
      //.rhita_o(combined_rhita[i]),
      .rhita_o(),
      .rhitb_o(combined_fetch_success[i])
    );
  end endgenerate

endmodule
