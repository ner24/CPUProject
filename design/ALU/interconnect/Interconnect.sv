module eu_interconnect import exec_unit_dtypes::*; #(
  parameter NUM_CHANNELS = 2, //should be at least 2
  parameter NUM_UNITS = 2 //arbitration channel width
) (
  inout wire type_icon_channel ports [NUM_UNITS-1:0]; //TODO: assert cannot be 'x. Most likely means being driven
                                                      //from multiple places nothing should be outputting x anyway
);
  localparam ARB_CH_WIDTH = $clog2(NUM_UNITS);

  type_icon_channel [NUM_CHANNELS-1:0] channels;
  wire [ARB_CH_WIDTH-1:0] arb_channels [NUM_UNITS-2:0] [NUM_CHANNELS-1:0];

  generate for(genvar ch_idx = 0; ch_idx < NUM_CHANNELS; ch_idx++) begin
    wire [ARB_CH_WIDTH-1:0] arb_inputs [NUM_UNITS-1:0] [2:0];
    wire [2:0] arb_selects [NUM_UNITS-1:0];
    for(genvar i = 0; i < NUM_UNITS; i++) begin: g_arbiter_channels
      comparator_3Input #(
        .DATA_WIDTH(ARB_CH_WIDTH),
        .GREATER_OR_LESS(0)
      ) (
        .values(),
        .select(arb_selects[i])
      );
    end
  end endgenerate

endmodule
