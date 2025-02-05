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
    //hbr is also the ~valid flag
    //so, to initialise memory to all invalid with all 0s, use n_hbr instead
    logic n_hbr;
    type_exec_unit_data data;
  } type_xbuf_entry;

  //request validity
  //when both alu and icon have valid requests, prioritise
  //the icon unless the RAM is full
  //More generally, for RX and TX, the input should always take priority over output (apart from when ram is full)
  wire req_valid_int;
  wire in_valid_int;
  logic [CACHE_IDX_WIDTH-1:0] num_elements_tracker;
  wire is_ram_full;
  
  assign is_ram_full = num_elements_tracker == ((CACHE_IDX_WIDTH**2)-1);


  //RAM port wires
  wire rhit;
  wire ram_ready_to_write;
  wire ram_entry_ready_to_use; //i.e. ram entry contains valid entry ready to be used in alu

  wire type_xbuf_entry rentry;
  type_exec_unit_addr raddr;
  type_xbuf_entry wentry;
  type_exec_unit_addr waddr;

  wire ram_we;
  wire ram_re;

  // --------------------
  // input DFF
  // --------------------

  wire in_dff_we;
  assign in_dff_we = in_valid_int & ram_ready_to_write;

  type_exec_unit_addr  in_addr_q;
  type_exec_unit_data  in_data_q;
  logic                in_valid_q;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      in_addr_q = 'b0;
      in_data_q = 'b0;
      in_valid_q = 'b0;
    end else if(in_dff_we) begin
      in_addr_q = in_addr_i;
      in_data_q = in_data_i;
      in_valid_q = in_valid_i;
    end else if (in_valid_q) begin
      in_valid_q = 1'b0;
    end
  end

  // ------------------------------
  // Output HBR update DFF
  // ------------------------------

  wire out_dff_we;
  assign out_dff_we = req_valid_int & ram_entry_ready_to_use;

  type_exec_unit_addr addr_to_update_n_hbr_q;
  logic addr_to_update_n_hbr_q_valid;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      addr_to_update_n_hbr_q <= 'b0;
      addr_to_update_n_hbr_q_valid <= 'b0;
    end else begin
      if(out_dff_we) begin
        addr_to_update_n_hbr_q <= req_addr_i;
        addr_to_update_n_hbr_q_valid <= 1'b1;
      end else if (addr_to_update_n_hbr_q_valid) begin
        addr_to_update_n_hbr_q_valid <= 1'b0;
      end
    end
  end

  //validity assignments (added here as it depends on input DFF)
  //because priority should only be given to req if in and in_q are low
  //note that alu_valid and icon_valid cannot be high at same time
  wire in_not_active;
  assign in_not_active = ~(in_valid_i | in_valid_q);
  assign req_valid_int = req_valid_i & ( in_not_active | is_ram_full );
  assign in_valid_int = in_valid_i & ~is_ram_full & ~addr_to_update_n_hbr_q_valid;

  // ------------------------------
  // RAM port assignments
  // ------------------------------
  always_comb begin
    if(in_valid_int) begin
      waddr = in_addr_q;
      raddr = in_addr_i;
    end else begin
      waddr = addr_to_update_n_hbr_q;
      raddr = req_addr_i;
    end
  end

  assign ram_ready_to_write = ~rentry.n_hbr;
  assign ram_entry_ready_to_use = rhit & rentry.n_hbr;
  always_comb begin
    if (in_valid_q) begin
      wentry.n_hbr = 1'b1;
      wentry.data = in_data_q;
    end else if (addr_to_update_n_hbr_q_valid) begin
      wentry.n_hbr = 1'b0;
      wentry.data = 'bx;
    end
  end
  assign ram_we = in_valid_q | addr_to_update_n_hbr_q_valid;
  assign ram_re = in_valid_int | req_valid_int;
  
  cache_DP #(
    .IDX_BITS(NUM_IDX_BITS),
    .DATA_WIDTH($bits(type_xbuf_entry)),
    .ADDR_WIDTH($bits(type_exec_unit_addr))
  ) ram (
    .clk(clk),
    .reset_n(reset_n),

    .addra_i(waddr),
    .addrb_i(raddr),

    .wdata_i(wentry),

    .cea_i(ram_we),
    .ceb_i(ram_re),
    .we_i(1'b1), //means rdataa and rhita will do nothing

    .rdataa_o(), //not used
    .rdatab_o(rentry),
    .rhita_o(), //not used
    .rhitb_o(rhit)
  );

  assign resp_success_o = rhit & rentry.n_hbr;
  assign in_success_o = in_dff_we;

  assign resp_data_o = rentry.data;

  always_ff @(posedge clk) begin
    if (~reset_n) begin
      num_elements_tracker = 'b0;
    end else begin
      //note that this updates in sync with ram_we
      //the memory itself updates a cycle after ram_we
      if(in_valid_q) begin
        num_elements_tracker = num_elements_tracker + 1;
      end else if (addr_to_update_n_hbr_q_valid) begin
        num_elements_tracker = num_elements_tracker - 1;
      end
    end
  end
  /*counter_JK #(.WIDTH(CACHE_IDX_WIDTH)) num_unread_elements_ctr (
    .clk(clk),
    .reset_n(reset_n),
    .set(1'b0),
    .set_val({CACHE_IDX_WIDTH{1'bx}}), //not used
    .rst_val({CACHE_IDX_WIDTH{1'b0}}),
    .trig(in_dff_we | resp_success_o),
    .inc_or_dec(resp_success_o & ~in_dff_we),
    .q(num_elements_tracker)
  );*/

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
