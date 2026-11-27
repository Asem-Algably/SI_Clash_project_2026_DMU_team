vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover +SEQ=golden
add wave -position insertpoint sim:/top/sync_system_top_test_vif/*
onfinish stop
run -all
coverage save sync_system_top_tb.ucdb
vcover report sync_system_top_tb.ucdb -details -all -output coverage_rpt_sync_system_top.txt
quit -f
