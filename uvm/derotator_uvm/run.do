vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
if {![batch_mode]} { add wave -position insertpoint sim:/top/derotator_test_vif/* }
onerror {quit -f}
onfinish stop
run -all
do coverage_waivers.do
coverage save derotator_tb.ucdb
vcover report derotator_tb.ucdb -details -all -output coverage_rpt_derotator.txt
quit -f
