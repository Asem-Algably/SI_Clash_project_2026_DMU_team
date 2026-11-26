vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
add wave -position insertpoint sim:/top/str_top_test_vif/*
onfinish stop
run -all
coverage save str_top_tb.ucdb
vcover report str_top_tb.ucdb -details -all -output coverage_rpt_str_top.txt
quit -f
