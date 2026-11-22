vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
add wave -position insertpoint sim:/top/derotator_test_vif/*
coverage save derotator_tb.ucdb -onexit
run -all
vcover report derotator_tb.ucdb -details -all -output coverage_rpt_derotator.txt
