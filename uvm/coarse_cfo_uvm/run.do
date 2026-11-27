vlib work
vlog -f src_files.list +cover -covercells

vsim -voptargs="+acc" work.top -classdebug -uvmcontrol=all -cover -assertdebug

# Safe wave commands (GUI/interactive only)
if {![batch_mode]} {
    if {[llength [find signals /top/*vif*]] > 0} {
        add wave -position insertpoint sim:/top/*vif*/*
    }
    if {[llength [find instances /top/dut]] > 0} {
        add wave -position insertpoint sim:/top/dut/*
    }
}
onerror {quit -f}

onfinish stop
run -all

do coverage_waivers.do
coverage save coarse_cfo_core_tb.ucdb
vcover report coarse_cfo_core_tb.ucdb -details -all -output coverage_rpt_coarse_cfo_core.txt
quit -f