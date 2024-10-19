ROOT_DIR_ABS:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
VIVADO_DIR:=$(ROOT_DIR_ABS)/vivado

env_setup:
	mkdir -p $(VIVADO_DIR)

sim_alpu: env_setup
	cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/initProject.tcl

#NOTE: vivado -mode batch -source test.tcl -tclargs 1 7 to pass command line args
#if { $argc != 2 } {
#        puts "The script requires two numbers to be input."
#        puts "For example, tclsh add.tcl 2 5".
#        puts "Please try again."
#    } else {
#        puts [expr [lindex $argv 0] + [lindex $argv 1\\]]
#    }
