#convert args to dict
#dict arg_dict $args
dict with argv {

  #get script path. Assumes batch command passes absolute path to script in -source arg
  set script_path [ file dirname [ file normalize [ info script ] ] ]
  set root_dir $script_path/..

  set part_name xczu7ev-ffvc1156-2-e

  set xpr_dir $script_path/vivado/run
  set xpr_name proj_cpu.xpr
  set xpr $xpr_dir/$xpr_name

  set simset_name sim_test
  #set designset_name cpu_srcs #stick to default sources (sources_1)

  #create new project if arg resetproj = 1
  if {![info exists resetproj]} {
    set resetproj 0
  }
  if {($resetproj == 1) || (![file exists $xpr])} {
    puts "Creating/Recreating project"
    create_project proj_cpu $xpr_dir -part $part_name -force
    set_property source_mgmt_mode None [current_project]
    
    #add design files
    add_files $root_dir/design -verbose
    add_files $root_dir/interfaces -verbose
    #set_property top alpu [get_fileset sources_1]

    #add sim files
    create_fileset -simset $simset_name -verbose
    current_fileset -simset [get_filesets $simset_name] -verbose
    add_files -fileset $simset_name $root_dir/sim -verbose

    #set properties
    set_property -name {xsim.compile.xvlog.more_options} -value "-L uvm -d MODE_SIMULATION -i $root_dir" -objects [get_fileset $simset_name] -verbose
    set_property -name {xsim.simulate.custom_tcl} -value "$script_path/runSim.tcl" -objects [get_fileset $simset_name] -verbose
    set_property -name {xsim.simulate.runtime} -value "10000ns" -objects [get_fileset $simset_name] -verbose
  } else {
    #faster way but only use if sources havn't been moved around
    puts "Opening project"
    open_project $xpr
  }

  #set design top module
  puts "Evalutaing module_top param"
  if {[info exists module_top]} {
    puts "Setting design top module to $module_top"
    #set_property top $module_top [get_fileset sources_1]
  } else {
    echo "No design top module specified"
    exit
  }

  #check job type exists
  puts "Job type: $job_type"
  if {![info exists job_type]} {
    puts "No job type specified"
    exit
  }

  #setup jobs
  switch $job_type {
    simlint {
      if {[info exists sim_module_top]} { 
        set_property top $sim_module_top [get_fileset $simset_name]
      } else {
        puts "Job requires sim_module_top but it is not specified"
        exit
      }

      puts "Running sim lint"
      update_compile_order -fileset $simset_name
      synth_design -top $sim_module_top -include_dirs "$root_dir" -lint
    }

    sim {
      if {[info exists sim_module_top]} { 
        puts "Setting sim top testbench to $sim_module_top"
        set_property top $sim_module_top [get_fileset $simset_name]
      } else {
        puts "Job requires sim_module_top but it is not specified"
        exit
      }

      puts "Running sim job"
      update_compile_order -fileset $simset_name -verbose
      launch_simulation -simset $simset_name
    }

    lint {
      puts "Running design lint"
      update_compile_order -fileset sources_1
      synth_design -top $module_top -include_dirs "$root_dir" -lint
    }

    elab {
      puts "Running design elab"
      update_compile_order -fileset sources_1
      synth_design -top $module_top -include_dirs "$root_dir" -rtl
    }

    default {
      puts "Unrecognised job type: $job_type"
      exit
    }

    #TODO: synthesis, power, timing analysis jobs
  }

  #gui and auto closing
  if {[info exists open_gui]} {
    start_gui
  #if open_gui exists, do not auto close even if it is specified
  } elseif {[info exists auto_close]} {
    puts "Auto close specified and so will exit"
    exit
  }
}
