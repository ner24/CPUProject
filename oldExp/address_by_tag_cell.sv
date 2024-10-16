module address_by_tag_cell #(
  parameter DATA_WIDTH = 16,
  parameter TAG_ADDRESS_WITDH = 8
) (
  input  wire clk,
  input  wire reset_n,

  input  wire  read_en_i,
  input  wire  write_en_i,
  input  wire  tag_i,
  input  wire  wdata_i,
  output logic rdata_o
);


  logic [DATA_WIDTH-1:0]        data;
  logic [TAG_ADDRESS_WITDH-1:0] stored_tag;

  assign rdata_o = (&(tag_i ^~ stored_tag) & read_en_i) ? data : '0;

  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      data       <= '0;
      stored_tag <= '0;
    end else if (write_en_i) begin
      //TODO: implement
      rdata_o <= '0;
    end else if (read_en_i) begin
      rdata_o <= &(tag_i ^~ stored_tag) ? data : '0;
    end
  end
endmodule
