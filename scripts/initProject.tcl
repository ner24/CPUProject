#get script path. Assumes batch command passes absolute path to script in -source arg
set script_path [ file dirname [ file normalize [ info script ] ] ]
set root_dir $script_path/..

create_project proj_cpu $script_path/vivado/run -part xczu7ev-ffvc1156-2-e -force
set_property source_mgmt_mode None [current_project]

#add design files
add_files $root_dir/design
add_files $root_dir/interfaces
set_property top alpu [get_fileset sources_1]
#update_compile_order -fileset sources_1

#add sim files
set simset_name sim_test
create_fileset -simset $simset_name
current_fileset -simset [get_filesets $simset_name]
add_files -fileset $simset_name $root_dir/sim

set_property top alpu_tb_top [get_fileset $simset_name]
update_compile_order -fileset $simset_name

set_property -name {xsim.compile.xvlog.more_options} -value "-L uvm -d MODE_SIMULATION -i $root_dir" -objects [get_fileset $simset_name]
set_property -name {xsim.simulate.custom_tcl} -value "$script_path/runSim.tcl" -objects [get_fileset $simset_name]
set_property -name {xsim.simulate.runtime} -value "10000ns" -objects [get_fileset $simset_name]

launch_simulation -simset $simset_name

#start_gui

#note: look at log_saif for power estimation in simulation
