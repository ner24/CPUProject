`include "design_parameters.sv"

module eu_xbuf import pkg_dtypes::*; #(
  parameter NUM_IDX_BITS = 2 //buffer sizes equal 2**NUM_IDX_BITS
) (
  input wire clk,
  input wire reset_n,

  //input data interface
  input  wire type_exec_unit_addr  in_addr_i,
  input  wire type_exec_unit_data  in_data_i,
  input  wire                      in_valid_i,
  output wire                      in_success_o,

  //request and read interface
  input  wire type_exec_unit_addr  req_addr_i,
  input  wire                      req_valid_i,
  output wire type_exec_unit_data  resp_data_o,
  output wire                      resp_success_o

);
  localparam CACHE_IDX_WIDTH = NUM_IDX_BITS;

  typedef struct packed {
    logic hbr;
    type_exec_unit_data data;
  } type_xbuf_entry;

  //request validity
  //when both alu and icon have valid requests, prioritise
  //the icon unless the RAM is full
  //More generally, for RX and TX, the input should always take priority over output (apart from when ram is full)
  wire req_valid_int;
  wire in_valid_int;
  wire [CACHE_IDX_WIDTH-1:0] num_elements_tracker;
  wire is_ram_full;
  
  assign is_ram_full = num_elements_tracker == ((CACHE_IDX_WIDTH**2)-1);
  assign req_valid_int = req_addr_i & (~in_valid_i | is_ram_full);
  assign in_valid_int = in_valid_i & ~is_ram_full;

  //alu_valid and icon_valid cannot be high at same time


  //RAM port wires
  wire rhit;
  wire ram_ready_to_write;
  wire ram_entry_ready_to_use;

  wire type_xbuf_entry rentry;
  type_xbuf_entry wentry;

  wire ram_we;
  wire ram_re;

  // --------------------
  // input DFF
  // --------------------

  wire in_dff_we;
  assign in_dff_we = in_valid_int & ram_ready_to_write & req_valid_i;

  type_exec_unit_addr  in_addr_q;
  type_exec_unit_data  in_data_q;
  logic                in_valid_q;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      in_addr_q = 'b0;
      in_data_q = 'b0;
      in_valid_q = 'b0;
    end else if(in_dff_we) begin
      in_addr_q = in_data_i;
      in_data_q = in_data_i;
      in_valid_q = in_valid_i;
    end
  end

  counter_JK #(.WIDTH(CACHE_IDX_WIDTH)) num_unread_elements_ctr (
    .clk(clk),
    .reset_n(reset_n),
    .set(1'b0),
    .set_val({CACHE_IDX_WIDTH{1'bx}}), //not used
    .rst_val({CACHE_IDX_WIDTH{1'b0}}),
    .trig(in_dff_we | resp_success_o),
    .inc_or_dec(resp_success_o & ~in_dff_we),
    .q(num_elements_tracker)
  );

  // ------------------------------
  // Output HBR update DFF
  // ------------------------------

  wire out_dff_we;
  assign out_dff_we = req_valid_int & ram_entry_ready_to_use;

  type_exec_unit_addr addr_to_update_hbr_q;
  logic addr_to_update_hbr_q_valid;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      addr_to_update_hbr_q <= 'b0;
      addr_to_update_hbr_q_valid <= 'b0;
    end else begin
      if(out_dff_we) begin
        addr_to_update_hbr_q <= req_addr_i;
        addr_to_update_hbr_q_valid <= 1'b1;
      end else begin
        addr_to_update_hbr_q_valid <= 1'b0;
      end
    end
  end

  // ------------------------------
  // RAM port assignments
  // ------------------------------
  assign ram_ready_to_write = rhit & rentry.hbr;
  assign ram_entry_ready_to_use = rhit & ~rentry.hbr;
  always_comb begin
    if (in_valid_int) begin
      wentry.hbr = 1'b0;
      wentry.addr = in_addr_q;
      wentry.data = in_data_q;
    end else if (req_valid_int) begin
      wentry.hbr = 1'b1;
      wentry.data = 'bx;
      wentry.addr = req_addr_i;
    end
  end
  assign ram_we = in_valid_int ? in_valid_q :
                  req_valid_int ? addr_to_update_hbr_q_valid : 1'b0;
  assign ram_re = in_valid_int | req_valid_int;

  cache_DP #(
    .IDX_BITS(NUM_IDX_BITS),
    .DATA_WIDTH($bits(type_xbuf_entry)),
    .ADDR_WIDTH($bits(type_exec_unit_addr))
  ) ram (
    .clk(clk),
    .reset_n(reset_n),

    .addra_i(wentry.addr),
    .addrb_i(rentry.addr),

    .wdata_i(wentry.data),

    .cea_i(ram_we),
    .ceb_i(ram_re),
    .we_i(ram_we), //means rdataa and rhita will do nothing

    .rdataa_o(), //not used
    .rdatab_o(rentry),
    .rhita_o(), //not used
    .rhitb_o(rhit)
  );

  assign resp_success_o = ~rentry.hbr;
  assign in_success_o = in_dff_we;

  assign resp_data_o = rentry.data;

endmodule

//has been read buffer
/*logic [CACHE_IDX_WIDTH-1:0] has_been_read_arr;
generate for (genvar i = 0; i < 2**CACHE_IDX_WIDTH; i++) begin
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      has_been_read_arr[i] = 1'b0;
    end else begin
      if(in_valid_int) begin
        
      end else begin
        
      end
    end
  end
end endgenerate*/

//swap dff. Dont think is needed. Assuming synth can manage proper clock propagation across
//chained memory units properly
/*type_exec_unit_addr addr_to_update_hbr_q [1:0];
wire type_icon_tx_channel addr_to_update_hbr_q_out;
logic out_dff_swap_state; //r = 0, w = 1
generate for (genvar i = 0; i < 2; i++) begin
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      addr_to_update_hbr_q[i] <= 'b0;
    end else if(out_dff_we & (i ? in_dff_swap_state : ~in_dff_swap_state)) begin
      addr_to_update_hbr_q[i] <= req_addr_i;
    end
  end
end endgenerate
always_ff @(posedge clk) begin
  if(~reset_n) begin
    out_dff_swap_state <= 1'b0;
  end else if(out_dff_we) begin
    out_dff_swap_state <= ~out_dff_swap_state;
  end
end
assign addr_to_update_hbr_q_out = addr_to_update_hbr_q[out_dff_swap_state];*/
