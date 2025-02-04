proc set_module_top {mod_top} {
  set module_top "$mod_top"
}

proc set_sim_module_top {mod_top} {
  set sim_module_top "$mod_top"
}

proc simlint {} {
  global root_dir
  global sim_module_top
  global simset_name
  global mode_sim_def_file

  if {[info exists sim_module_top]} { 
    set_property top $sim_module_top [get_fileset $simset_name]
  } else {
    puts "Job requires sim_module_top but it is not specified"
    exit
  }
  puts "Running sim lint"

  add_files $mode_sim_def_file -verbose
  set_property file_type "Verilog Header" [get_files $mode_sim_def_file]
  set_property is_global_include true [get_files $mode_sim_def_file]
  update_compile_order -fileset $simset_name

  synth_design -top $sim_module_top -include_dirs "$root_dir/projectHeaders" -lint
}

#proc sim {sim_module_top simset_name mode_sim_def_file} {
proc sim {} {
  global sim_module_top
  global simset_name
  global mode_sim_def_file

  if {[info exists sim_module_top]} { 
    puts "Setting sim top testbench to $sim_module_top"
    set_property top $sim_module_top [get_fileset $simset_name]
  } else {
    puts "Job requires sim_module_top but it is not specified"
    exit
  }
  puts "Running sim job"
  
  add_files $mode_sim_def_file -verbose
  set_property file_type "Verilog Header" [get_files $mode_sim_def_file]
  set_property is_global_include true [get_files $mode_sim_def_file]
  update_compile_order -fileset $simset_name -verbose

  launch_simulation -simset $simset_name
}

proc lint {} {
  global root_dir
  global module_top
  global mode_sim_def_file

  puts "Running design lint"
  remove_files $mode_sim_def_file -quiet
  update_compile_order -fileset sources_1

  synth_design -top $module_top -include_dirs "$root_dir/projectHeaders" -lint
}

proc elab {} {
  global root_dir
  global module_top
  global mode_sim_def_file

  puts "Running design elab"
  remove_files $mode_sim_def_file -quiet
  update_compile_order -fileset sources_1
  
  synth_design -top $module_top -include_dirs "$root_dir/projectHeaders" -rtl
}

#TODO: synthesis, power, timing analysis jobs

