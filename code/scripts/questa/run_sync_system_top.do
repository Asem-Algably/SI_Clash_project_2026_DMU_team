# Single-file TB runner — all TBs listed, exactly ONE uncommented at a time.
#
# HOW TO USE:
#   1. Open this file in a text editor (Notepad++, VS Code, etc.)
#   2. Comment out ALL the "do run_tb_<name>.do" lines EXCEPT the one you want
#   3. Save
#   4. In QuestaSim console:  do run_one_tb.do
#   5. The selected TB launches in GUI with waves added automatically
#
# Each section is self-contained: compile + vsim + wave add + run
# Just uncomment the ONE you want to run.
#
# NOTE: Run "do compile_all.do" ONCE before this (compiles all RTL + TBs).

# ============================================================================
# TB 6: tb_sync_system_top
# ============================================================================
echo "=========================================="
echo "Running tb_sync_system_top (full integration)"
echo "=========================================="

vsim -gui -voptargs=+acc work.tb_sync_system_top

view wave
add wave -divider "Input"
add wave -position insertpoint sim:/tb_sync_system_top/clk
add wave -position insertpoint sim:/tb_sync_system_top/rst_n
add wave -position insertpoint sim:/tb_sync_system_top/in_sample_valid
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/in_sample_i
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/in_sample_q
add wave -position insertpoint sim:/tb_sync_system_top/start_of_burst

add wave -divider "STR Output"
add wave -position insertpoint sim:/tb_sync_system_top/u_dut/str_valid
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/u_dut/str_sym_i
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/u_dut/str_sym_q
add wave -position insertpoint sim:/tb_sync_system_top/u_dut/str_lock

add wave -divider "Coarse CFO"
add wave -position insertpoint sim:/tb_sync_system_top/u_dut/coarse_valid
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/u_dut/coarse_est

add wave -divider "FSM State"
add wave -position insertpoint -radix unsigned sim:/tb_sync_system_top/u_dut/fsm_state

add wave -divider "Derotator Output"
add wave -position insertpoint sim:/tb_sync_system_top/out_sym_valid
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/out_sym_i
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/out_sym_q

add wave -divider "Costas"
add wave -position insertpoint sim:/tb_sync_system_top/u_dut/costas_mode
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/u_dut/costas_freq_adj
add wave -position insertpoint sim:/tb_sync_system_top/u_dut/costas_lock

add wave -divider "Top Outputs"
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/coarse_cfo_est
add wave -position insertpoint -radix decimal sim:/tb_sync_system_top/fine_cfo_est
add wave -position insertpoint sim:/tb_sync_system_top/lock_detect
add wave -position insertpoint -radix hex sim:/tb_sync_system_top/dft_obs_data

add wave -divider "Counter"
add wave -position insertpoint -radix unsigned sim:/tb_sync_system_top/out_sym_count

run -all
wave zoom full

# ============================================================================
# END OF FILE
# ============================================================================
echo "=========================================="
echo "TB run complete"
echo "To run a different TB:"
echo "  1. Open run_one_tb.do in a text editor"
echo "  2. Comment out the current TB section"
echo "  3. Uncomment the desired TB section"
echo "  4. Save and re-run: do run_one_tb.do"
echo "=========================================="