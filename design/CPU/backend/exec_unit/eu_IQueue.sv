module eu_IQueue import pkg_dtypes::*; #(
  parameter LOG2_QUEUE_LENGTH = 4,
  parameter EU_LOG2_IQUEUE_NUM_QUEUES = 2,
  parameter NUM_PARALLEL_INSTR_DISPATCHES = 4,
  parameter logic [LOG2_NUM_EXEC_UNITS-1:0] EU_IDX = 'b0
) (
  input  wire clk,
  input  wire reset_n,

  input  wire type_iqueue_entry dispatched_instr_i       [NUM_PARALLEL_INSTR_DISPATCHES-1:0],
  input  wire                   dispatched_instr_valid_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0],
  input  wire [LOG2_NUM_EXEC_UNITS-1:0] dispatched_instr_alloc_euidx_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0],
  
  //cannot accept entries when any required buffer is full
  //i.e. tell front end to retry dispatch if this flag is high
  //this is fine as front end cannot move to next batch until all 
  //cells in the rename ILN are free
  output logic                  is_full_o,
  output wire type_iqueue_entry curr_instr_to_exec_o,
  input  wire                   ready_for_next_instr_i, //tell queue to stall if not ready
  output wire                   curr_instr_to_exec_valid_o
);
  localparam NUM_QUEUES = 2**EU_LOG2_IQUEUE_NUM_QUEUES;

  // ----------------------------------
  // Curr instr round robin counter
  // ----------------------------------
  wire is_empty [NUM_QUEUES-1:0]; //is buffer empty?

  logic [EU_LOG2_IQUEUE_NUM_QUEUES-1:0] curr_instr_rr_ctr;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      curr_instr_rr_ctr = 'b0;
    end else begin
      if(ready_for_next_instr_i & (~is_empty[curr_instr_rr_ctr])) begin
        curr_instr_rr_ctr = curr_instr_rr_ctr + 1'b1;
      end
    end
  end
  wire [NUM_QUEUES-1:0] buf_enables;
  generate for(genvar i = 0; i < NUM_QUEUES; i++) begin
    assign buf_enables[i] = curr_instr_rr_ctr == i;
  end endgenerate

  // --------------------------------------------
  // Dispatch instruction shift and remove gaps
  // (where gaps are lanes in the dispatch bus where the instruction
  // is not valid/relevant to this eu)
  // --------------------------------------------
  wire dispatched_instr_valid_relevant [NUM_PARALLEL_INSTR_DISPATCHES-1:0]; //relevant meaning euidx lines up with this eu
  generate for (genvar i = 0; i < NUM_PARALLEL_INSTR_DISPATCHES; i++) begin
    assign dispatched_instr_valid_relevant[i] = dispatched_instr_valid_i[i] & (dispatched_instr_alloc_euidx_i[i] == EU_IDX);
  end endgenerate

  //intermediate stores the instructions after shifting and moving all gaps to highest channel idxs
  wire type_iqueue_entry dispatched_instr_intermediate       [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  wire                   dispatched_instr_valid_intermediate [NUM_PARALLEL_INSTR_DISPATCHES-1:0];

  logic [$clog2(NUM_PARALLEL_INSTR_DISPATCHES)-1:0] least_significant_valid_instr;

  generate for (genvar i = 0; i < NUM_PARALLEL_INSTR_DISPATCHES; i++) begin
    wire type_iqueue_entry dispatched_instr_intermediate2;
    wire                   dispatched_instr_valid_intermediate2;

    if(i != (NUM_PARALLEL_INSTR_DISPATCHES-1)) begin
      assign dispatched_instr_intermediate2 = dispatched_instr_valid_relevant[i] ?
                                                dispatched_instr_i[i]
                                              : dispatched_instr_i[i+1];
      assign dispatched_instr_valid_intermediate2 = dispatched_instr_valid_relevant[i] ?
                                                      dispatched_instr_valid_relevant[i]
                                                    : dispatched_instr_valid_relevant[i+1];
    end else begin
      assign dispatched_instr_intermediate2 = dispatched_instr_valid_relevant[i] ?
                                                dispatched_instr_i[i]
                                              : 'b0;
      assign dispatched_instr_valid_intermediate2 = dispatched_instr_valid_relevant[i] ?
                                                      dispatched_instr_valid_relevant[i]
                                                    : 'b0;
    end
    if(i != 'd0) begin
      assign dispatched_instr_intermediate[i] = dispatched_instr_valid_relevant[i-1] | (i == least_significant_valid_instr) ?
                                                  dispatched_instr_intermediate2
                                                : 'b0;
      assign dispatched_instr_valid_intermediate[i] = dispatched_instr_valid_relevant[i-1] | (i == least_significant_valid_instr) ?
                                                        dispatched_instr_valid_intermediate2
                                                      : 'b0;
    end else begin
      assign dispatched_instr_intermediate[i]       = dispatched_instr_intermediate2;
      assign dispatched_instr_valid_intermediate[i] = dispatched_instr_valid_intermediate2;
    end
  end endgenerate

  //rotate around to align with head of round robin ctr
  //(i.e the instr in instr_intermediate[0] should go to buffer at idx 
  //curr_instr_rr_ctr and instr_intermediate[1] should go to curr_instr_rr_ctr+1 etc.)
  type_iqueue_entry dispatched_instr       [NUM_QUEUES-1:0];
  logic             dispatched_instr_valid [NUM_QUEUES-1:0];
  wire is_full [NUM_QUEUES-1:0]; //directly from buffers

  logic [EU_LOG2_IQUEUE_NUM_QUEUES-1:0] tot_num_valid_instr_to_be_inserted;
  logic [EU_LOG2_IQUEUE_NUM_QUEUES-1:0] iqueue_idx_alloc_ctr;
  always_comb begin
    tot_num_valid_instr_to_be_inserted = 'd0;
    for(int c = 0; c < NUM_QUEUES; c++) begin
      if (dispatched_instr_valid_intermediate[c+least_significant_valid_instr]) begin
        tot_num_valid_instr_to_be_inserted++;
      end
    end
  end
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      iqueue_idx_alloc_ctr = 'b0;
    end else begin
      if(tot_num_valid_instr_to_be_inserted != 'd0) begin
        iqueue_idx_alloc_ctr = iqueue_idx_alloc_ctr + tot_num_valid_instr_to_be_inserted;
      end
    end
  end

  //represents the lowest dispatch bus idx that is valid and relevant
  //Note: this can also be done by converting the output to one hot by only making the most significant bit disable
  //the outputs of the lesser significant bits and then passing into a one-hot to binary encoder. Might make a simpler circuit
  always_comb begin
    least_significant_valid_instr = 'd0;
    for(int c = 0; c < NUM_PARALLEL_INSTR_DISPATCHES; c++) begin
      if (dispatched_instr_valid_relevant[c]) begin
        least_significant_valid_instr = c[$clog2(NUM_PARALLEL_INSTR_DISPATCHES)-1:0];
        break;
      end
    end
  end

  logic [$clog2(NUM_PARALLEL_INSTR_DISPATCHES)-1:0] idx;
  always_comb begin
    is_full_o = 1'b0;
    idx = least_significant_valid_instr + iqueue_idx_alloc_ctr;
    for (int i = 0; i < NUM_QUEUES; i++, idx++) begin
      dispatched_instr[i] = dispatched_instr_intermediate[idx];
      dispatched_instr_valid[i] = dispatched_instr_valid_intermediate[idx];
      is_full_o |= is_full[i] & dispatched_instr_valid[i];
    end
  end

  // ----------------------------------
  // Buffers
  // ----------------------------------
  assign curr_instr_to_exec_valid_o = ~is_empty[curr_instr_rr_ctr];

  wire type_iqueue_entry curr_instrs [NUM_QUEUES-1:0];
  assign curr_instr_to_exec_o = curr_instrs[curr_instr_rr_ctr];

  generate for(genvar i = 0; i < NUM_QUEUES; i++) begin
    fifo_buffer #(
      .LOG2_QUEUE_LENGTH(LOG2_QUEUE_LENGTH),
      .DATA_WIDTH($bits(curr_instr_to_exec_o))
    ) ram (
      .clk(clk),
      .reset_n(reset_n),

      .wdata_i(dispatched_instr[i]),
      .wvalid_i(dispatched_instr_valid[i]),

      .rdata_o(curr_instrs[i]),
      .rready_i(ready_for_next_instr_i & buf_enables[i]),

      .full_o(is_full[i]),
      .empty_o(is_empty[i])
    );
  end endgenerate

endmodule
