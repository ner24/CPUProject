module IQueue #( //WIP
  parameter QUEUE_SIZE_BIN = 4,
  parameter DATA_WIDTH = 16
) (
  input  wire clk,
  input  wire reset_n,

  input  wire  [DATA_WIDTH-1:0] in_data,
  input  wire                   in_valid, //entry to acccept is valid (specified by sender)
  
  output logic                  in_ready, //ready to accept entry
  input  wire                   out_ready, //receiver ready to accept output 
  output logic [DATA_WIDTH-1:0] out_data
);
  logic       rw_swap; //0 = read. 1 = write
  wire  [1:0] rw_swap_dist;
  assign rw_swap_dist[0] = rw_swap;
  assign rw_swap_dist[1] = ~rw_swap;
  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      rw_swap <= '0;
    end else begin
      rw_swap <= ~rw_swap;
    end
  end

  logic [(2**QUEUE_SIZE_BIN)-1:0] [DATA_WIDTH-1:0] mem [1:0];

  logic [QUEUE_SIZE_BIN-1:0] ptr_head [1:0];
  logic [QUEUE_SIZE_BIN-1:0] ptr_tail [1:0];

  generate for (genvar i = 0; i < 2; i++) begin: g_bank_logic
    always_ff @(posedge clk or negedge reset_n) begin: mem_behaviour
      if(~reset_n) begin
        mem[i]      <= '0;
        ptr_head[i] <= '0;
        ptr_tail[i] <= '1;
      end else begin
        if (rw_swap_dist[i]) begin
          if(in_valid & in_ready) begin
            mem[i][ptr_head[i]] = in_data;
            ptr_head[i] = ptr_head[i] + 1;
          end
        end else begin
          if(out_ready) begin
            out_data = mem[i][ptr_tail[i]];
            ptr_tail[i] = ptr_tail[i] + 1;
          end
        end
      end
    end
    always_comb begin : calc_in_ready
      in_ready = '0;
      for (int i = 0; i < 2; i++) begin
        in_ready |= ptr_head[i] == ptr_tail[i];
      end
    end
  end endgenerate

endmodule
