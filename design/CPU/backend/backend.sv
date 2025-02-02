module u_backend import pkg_dtypes::*; #(
  parameter NUM_ICON_CHANNELS = 4,
  parameter NUM_EXEC_UNITS = 4
) (
  //Dispatch bus
  //connects front end dispatch to all execution unit IQueues

  //Store buffer output
  //interconnect channel which sends data to MMU for str handling

  //mx register write
  //interconnect channel for writing values to mx registers in the MMU



);

  // Interconnect channels
  generate for (genvar icon_ch_idx = 0; icon_ch_idx < NUM_ICON_CHANNELS; icon_ch_idx++) begin
    
  end endgenerate

  
  //Interconnect controller


  
  //execution units


endmodule
