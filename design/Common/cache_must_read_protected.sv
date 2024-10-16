module cache_MRP # ( //must read protected cache

  //NUM_ENTRIES will equal 2**IDX_BITS
  //avoids having to have extra logic for out of
  //bound address checks
  parameter IDX_BITS = 2,

  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 8
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [ADDR_WIDTH-1:0] addr_i,
  input  wire  [DATA_WIDTH-1:0] wdata_i,

  input  wire                   ce_i,
  input  wire                   we_i,

  output logic [DATA_WIDTH-1:0] rdata_o,
  //if tag address does not match on read, then read is invalid
  output logic                  rvalid_o,
  //if address writing to has not already been read, then write has not been acknowledged
  output logic                  wack_o
);

  localparam TAG_ADDRESS_WITDH = ADDR_WIDTH - IDX_BITS;

  typedef struct packed {
    logic        [DATA_WIDTH-1:0] data;
    logic [TAG_ADDRESS_WITDH-1:0] stored_tag;
  } cache_entry;

  logic       has_been_read [(2**IDX_BITS)-1:0];
  //(* ram_style = "block" *) cache_entry ram [(2**IDX_BITS)-1:0];
  (* ram_style = "block" *) logic [(DATA_WIDTH+TAG_ADDRESS_WITDH)-1:0] ram [(2**IDX_BITS)-1:0];

  wire [IDX_BITS-1:0] idx;
  assign idx = addr_i[IDX_BITS-1:0];

  always_ff @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
      for (int i = 0; i < (2**IDX_BITS); i++) begin
        ram[i] <= '0;
      end
    end else if (ce_i) begin
      if (we_i) begin
        if (has_been_read[idx]) begin
          //ram[idx].data          <= wdata_i;
          //ram[idx].stored_tag    <= addr_i[ADDR_WIDTH-1:IDX_BITS];
          ram[idx]               <= {addr_i[ADDR_WIDTH-1:IDX_BITS], wdata_i};
          has_been_read[idx]     <= 1'b0;
          
          wack_o                 <= 1'b1;
        end else begin
          wack_o                 <= 1'b0;
        end
      end else begin
        //rdata_o            <= ram[idx].data;
        rdata_o            <= ram[idx][DATA_WIDTH-1:0];
        has_been_read[idx] <= 1'b1;
        //rvalid_o           <= ram[idx].stored_tag == addr_i[ADDR_WIDTH-1:IDX_BITS];
        rvalid_o           <= ram[idx][(DATA_WIDTH+TAG_ADDRESS_WITDH)-1:DATA_WIDTH];
      end
    end
  end
endmodule



