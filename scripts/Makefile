ROOT_DIR_ABS:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
VIVADO_DIR:=$(ROOT_DIR_ABS)/vivado

#these are passed from command line (e.g. make <target> open_gui=1 auto_close=1)
TCL_ARGS_EXTRA=
ifdef resetproj
$(info resetproj = $(resetproj))
TCL_ARGS_EXTRA+= resetproj $(resetproj)
endif
ifdef open_gui
$(info open_gui = $(open_gui))
TCL_ARGS_EXTRA+= open_gui $(open_gui)
endif
ifdef auto_close
$(info auto_close = $(auto_close))
TCL_ARGS_EXTRA+= auto_close $(auto_close)
endif
ifdef module_top
$(info module_top = $(module_top))
TCL_ARGS_EXTRA+= module_top $(module_top)
endif

env_setup:
	mkdir -p $(VIVADO_DIR)

#Generic
CMD_GENERIC_BASE:= cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/prj.tcl
open:
	$(CMD_GENERIC_BASE) -tclargs $(TCL_ARGS_EXTRA) job_type nothing
open_gui: #macro for opening vivado gui
	$(CMD_GENERIC_BASE) module_top tri_state_test open_gui 1 job_type nothing

#ALPU
CMD_ALPU_BASE:= cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/prj.tcl -tclargs module_top alpu sim_module_top alpu_tb_top $(TCL_ARGS_EXTRA)
open_alpu:
	$(CMD_ALPU_BASE) job_type nothing
sim_alpu: env_setup
	$(CMD_ALPU_BASE) job_type sim
simlint_alpu: env_setup
	$(CMD_ALPU_BASE) job_type simlint
elab_alpu: env_setup
	$(CMD_ALPU_BASE) job_type elab
lint_alpu: env_setup
	$(CMD_ALPU_BASE) job_type lint
sim_alpu_old: env_setup
	cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/initProject.tcl

#ALPU CACHE
CMD_ALPU_CACHE_BASE:= cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/prj.tcl -tclargs module_top alpu_cache $(TCL_ARGS_EXTRA)
open_alpu_cache: env_setup
	$(CMD_ALPU_CACHE_BASE) job_type nothing
lint_alpu_cache: env_setup
	$(CMD_ALPU_CACHE_BASE) job_type lint
elab_alpu_cache: env_setup
	$(CMD_ALPU_CACHE_BASE) job_type elab

#cache DP
CMD_CACHE_DP_BASE:= cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/prj.tcl -tclargs module_top cache_MRP_DP $(TCL_ARGS_EXTRA)
lint_cache_MRPDP: env_setup
	$(CMD_CACHE_DP_BASE) job_type lint
elab_cache_MRPDP: env_setup
	$(CMD_CACHE_DP_BASE) job_type elab
