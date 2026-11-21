vlib work
vlog -f src_files.list +cover -covercells

vsim -voptargs="+acc" work.top -classdebug -uvmcontrol=all -cover -assertdebug

# Resume on errors (Tcl command, NOT a vsim flag)
onerror {resume}

# Safe wave commands (won't stop the script if name is wrong)
if {[llength [find signals /top/*vif*]] > 0} {
    add wave -position insertpoint sim:/top/*vif*/*
} else {
    echo "WARNING: no *vif* instance under /top — check coarse_cfo_core_top.sv"
}

if {[llength [find instances /top/dut]] > 0} {
    add wave -position insertpoint sim:/top/dut/*
}

run -all

coverage save coarse_cfo_core_tb.ucdb -onexit
vcover report coarse_cfo_core_tb.ucdb -details -all -output coverage_rpt_coarse_cfo_core.txt