module eu_interconnect import pkg_dtypes::*; #(
  parameter NUM_CHANNELS = 2, //should be at least 2
  parameter NUM_UNITS = 2
) (
  //TODO: assert cannot be 'x. Most likely means being driven
  //from multiple places. Nothing should be outputting x anyway
  inout wire type_icon_channel ports [NUM_UNITS-1:0]
);
  type_icon_channel [NUM_CHANNELS-1:0] channels;



endmodule
