module cache_AddrTagMR_cell #(
  parameter DATA_WIDTH = 16,
  parameter TAG_ADDRESS_WITDH = 8
) (
  input  wire clk,
  input  wire reset_n,

  input  wire  ce_i,
  input  wire  we_i,
  input  wire  tag_i,
  input  wire  wdata_i,

  output logic has_been_read, //if low, must not be overwritten
  output logic rdata_o
);


  logic [DATA_WIDTH-1:0]        data;
  logic [TAG_ADDRESS_WITDH-1:0] stored_tag;

  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      data          <= '0;
      stored_tag    <= '0;
      has_been_read <= '0;
    end else if (ce_i) begin
      if (we_i) begin
        data          <= wdata_i;
        stored_tag    <= tag_i;
        has_been_read <= 1'b0;
        rdata_o       <= '0;
      end else begin
        rdata_o       <= &(tag_i ^~ stored_tag) ? data : '0;
        has_been_read <= 1'b1;
      end
    end else begin
      rdata_o         <= '0;
      has_been_read   <= '0;
    end
  end
endmodule


