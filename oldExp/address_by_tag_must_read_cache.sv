module cache_AddrTagMR # ( //TODO: finish implementation
  parameter NUM_ENTRIES = 16,
  parameter DATA_WIDTH = 16,
  parameter TAG_ADDRESS_WITDH = 8
) (
  input  wire  clk,
  input  wire  reset_n,

  input  wire [TAG_ADDRESS_WITDH-1:0] tag_i,
  input  wire       [DATA_WIDTH-1:0]  wdata_i,

  input  wire  ce_i,
  input  wire  we_i,

  output logic       [DATA_WIDTH-1:0] rdata_o
);

  typedef struct packed {
    logic        [DATA_WIDTH-1:0] data;
    logic [TAG_ADDRESS_WITDH-1:0] stored_tag;
    logic                         has_been_read;
  } cache_entry;
  cache_entry [NUM_ENTRIES-1:0] ram;
  
  wire  [NUM_ENTRIES-1:0] [$clog2(NUM_ENTRIES)-1:0] write_idx_int; //index to write to on we_i
  wire                    [$clog2(NUM_ENTRIES)-1:0] write_idx;
  assign write_idx          = write_idx_int[NUM_ENTRIES-1];
  assign write_idx_int[0]   = '0;
  generate for (genvar i = 1; i < NUM_ENTRIES; i++) begin
    localparam logic [$clog2(NUM_ENTRIES)-1:0] i_resized = i;
    assign write_idx_int[i] = ram[i].has_been_read ? i_resized : write_idx_int[i-1];
  end endgenerate
  /*always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      ram <= '0;
    end else if (ce_i & we_i) begin
      ram[write_idx].data          <= wdata_i;
      ram[write_idx].stored_tag    <= tag_i;
      ram[write_idx].has_been_read <= 1'b0;
    end
  end*/

  logic          [NUM_ENTRIES-1:0] [DATA_WIDTH-1:0] rdata_cell;
  generate for (genvar i = 0; i < NUM_ENTRIES; i++) begin
    assign rdata_o = rdata_cell[i];
  end endgenerate
  /*always_comb begin
    rdata_o = '0;
    for (int i = 0; i < NUM_ENTRIES; i++) begin
      rdata_o |= rdata_cell[i];
    end
  end*/

  generate for (genvar i = 0; i < NUM_ENTRIES; i++) begin
    always_ff @(posedge clk or negedge reset_n) begin
      if (~reset_n) begin
        ram[i] <= '0;
      end else if (ce_i) begin
        if (we_i) begin
          if (write_idx == i) begin
            ram[i].data          <= wdata_i;
            ram[i].stored_tag    <= tag_i;
            ram[i].has_been_read <= 1'b0;
          end
          rdata_cell[i] <= '0;
        end else begin
          rdata_cell[i]        <= tag_i == ram[i].stored_tag ? ram[i].data : '0;
          ram[i].has_been_read <= 1'b1;
        end
      end else begin
        rdata_cell[i]        <= '0;
      end
    end
  end endgenerate

endmodule
