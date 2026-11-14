# ============================================================================
# QuestaSim / ModelSim Full Integration Simulation Automation Script
# Project: SI-CLASH Real-Time Digital Synchronizer
# Usage:   In QuestaSim prompt: do code/scripts/questa/run_sync_system_top.do
# ============================================================================

vlib work
vmap work work

echo "=========================================="
echo "Compiling SI-CLASH Synchronizer RTL & TB..."
echo "=========================================="

vlog +acc -sv \
  code/rtl/str/gardner_ted_estimator.sv \
  code/rtl/str/modulo_1_controller.sv \
  code/rtl/str/parabolic_farrow_interpolator.sv \
  code/rtl/str/pI_loop.sv \
  code/rtl/str/str_top.sv \
  code/rtl/coarse_cfo/reset_sync.sv \
  code/rtl/coarse_cfo/complex_mult.sv \
  code/rtl/coarse_cfo/accumulator.sv \
  code/rtl/coarse_cfo/cordic_angle.sv \
  code/rtl/coarse_cfo/coarse_cfo_core.sv \
  code/rtl/coarse_cfo/coarse_cfo_axi_wrapper.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/lut_rom.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/quadrant_rotator.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/input_pipeline.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/complex_multiplier.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/Freq_word.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/NCO_accumulator.sv \
  +incdir+code/rtl/derotator code/rtl/derotator/derotator.sv \
  code/rtl/costas/slicer.sv \
  code/rtl/costas/phase_error.sv \
  code/rtl/costas/pi_filter.sv \
  code/rtl/costas/lock_detector.sv \
  code/rtl/costas/quad_check.sv \
  code/rtl/costas/costas_top.sv \
  code/rtl/costas/err_align.sv \
  code/rtl/top/burst_ctrl.sv \
  code/rtl/top/dft_mux.sv \
  code/rtl/top/sync_system_top.sv \
  code/tb/top/tb_sync_system_top.sv

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