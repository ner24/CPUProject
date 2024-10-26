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

env_setup:
	mkdir -p $(VIVADO_DIR)

#ALPU
sim_alpu_old: env_setup
	cd $(VIVADO_DIR); vivado -mode tcl -source $(ROOT_DIR_ABS)/initProject.tcl

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
