if not exist ./vivado mkdir vivado

cd vivado
vivado -mode tcl -source %~dp0\initProject.tcl
