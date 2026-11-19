vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
add wave -position insertpoint sim:/top/costas_top_test_vif/*
coverage save costas_top_tb.ucdb -onexit
run -all
#vcover report costas_top_tb.ucdb -details -all -output coverage_rpt_costas_top.txt
