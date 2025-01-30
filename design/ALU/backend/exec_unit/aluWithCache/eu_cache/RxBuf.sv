`include "design_parameters.sv"

module alpu_cache import pkg_dtypes::*; #(

) (
  input wire clk,
  input wire reset_n,

  //interconnect interface
  input  wire type_icon_tx_channel in_pkt,
  output wire                      success,

  //ALU interface
  input  wire type_exec_unit_addr  alu_req_addr,
  input  wire                      alu_req_valid,
  output wire                      alu_resp_data

);
  localparam CACHE_IDX_WIDTH = `EU_CACHE_NUM_IDX_BITS-1;

  //request validity
  //when both alu and icon have valid requests, prioritise
  //the icon unless the RAM is full
  wire alu_valid_int;
  wire icon_valid_int;
  wire [CACHE_IDX_WIDTH-1:0] num_elements_tracker;
  wire is_ram_full;

  assign is_ram_full = num_elements_tracker == (CACHE_IDX_WIDTH**2)-1;
  counter_JK #(.WIDTH(CACHE_IDX_WIDTH)) num_unread_elements_ctr (
    .clk(clk),
    .reset_n(reset_n),
    .set(1'b0),
    .set_val({CACHE_IDX_WIDTH{1'bx}}),
    .rst_val({CACHE_IDX_WIDTH{1'b0}}),
    .trig(),
    .inc_or_dec(),
    .q(num_elements_tracker)
  );
  assign alu_valid_int = alu_req_addr & (~in_pkt.valid | is_ram_full);
  assign icon_valid_int = in_pkt.valid & ~is_ram_full;


  type_icon_tx_channel in_pkt_q;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      in_pkt_q <= 1'b0;
    end else begin
      in_pkt_q <= in_pkt;
    end
  end

  //has been read buffer
  logic [CACHE_IDX_WIDTH-1:0] has_been_read_arr;
  generate for (genvar i = 0; i < 2**CACHE_IDX_WIDTH; i++) begin
    always_ff @(posedge clk) begin
      if(~reset_n) begin
        has_been_read_arr[i] = 1'b0;
      end else begin
        logic re, we;
        we = in_pkt.addr == i;
        re = alu_req_addr == i;
        
        //on collision, prioritise read over write
        //on collision, shortcut will be used if enabled
        //if disabled, reject write, next cycle update as normal
        if(re) begin
          has_been_read_arr[i] = 1'b1;
        end else if(we) begin
          has_been_read_arr[i] = 1'b0;
        end
      end
    end
  end endgenerate

  cache_DP #(
    .IDX_BITS(2),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(8)
  ) ram (
    .clk(clk),
    .reset_n(reset_n),

    .addra_i(),
    .addrb_i(),

    .wdata_i(),

    .cea_i(),
    .ceb_i(),
    .we_i(),

    .rdataa_o(),
    .rdatab_o(),
    .rhita_o(),
    .rhitb_o()
  );

endmodule
