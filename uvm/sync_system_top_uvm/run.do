vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover +SEQ=golden
add wave -position insertpoint sim:/top/sync_system_top_test_vif/*
coverage save sync_system_top_tb.ucdb -onexit
run -all
vcover report sync_system_top_tb.ucdb -details -all -output coverage_rpt_sync_system_top.txt
