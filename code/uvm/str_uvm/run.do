vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
add wave -position insertpoint sim:/top/str_top_test_vif/*
coverage save str_top_tb.ucdb -onexit
run -all
vcover report str_top_tb.ucdb -details -all -output coverage_rpt_str_top.txt
