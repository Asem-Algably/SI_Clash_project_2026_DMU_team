vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
add wave -position insertpoint sim:/top/costas_top_test_vif/*
onfinish stop
run -all
coverage save costas_top_tb.ucdb
vcover report costas_top_tb.ucdb -details -all -output coverage_rpt_costas_top.txt
quit -f
