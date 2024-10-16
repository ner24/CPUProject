module address_by_tag_cache # ( //TODO: finish implementation
  parameter NUM_ENTRIES = 2,
  parameter DATA_WIDTH = 16,
  parameter TAG_ADDRESS_WITDH = 8
) (
  input  wire clk,
  input  wire reset_n,

  input  wire tag_i,
  input  wire wdata_i,

  input  wire ce_i,
  input  wire we_i,

  output wire rdata_o
);

  wire read  = ce_i & ~we_i;
  wire write = ce_i & we_i;

  logic [NUM_ENTRIES-1:0] [DATA_WIDTH-1:0]        ram;
  logic [NUM_ENTRIES-1:0] [TAG_ADDRESS_WITDH-1:0] tag;

  //assign rdata_o = (ce_i & ~we_i) ? ram[tag_i] : '0;

  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      ram <= '0;
      tag <= '0;
    end else if (write) begin
      
    end else if (read) begin
      
    end
  end

endmodule
