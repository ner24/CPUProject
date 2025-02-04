//because vivado is painful to use
//define mode sim through a global file
//add it conditionally as a global include when running sim
//this does mean that vivado has to restart when switching
//between synth and sim (or this file can be removed/added from hierarchy
//manually in the IDE)
`define MODE_SIMULATION
