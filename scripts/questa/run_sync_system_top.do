# ============================================================================
# QuestaSim / ModelSim Full Integration Simulation Automation Script
# Project: SI-CLASH Real-Time Digital Synchronizer
# Usage:   In QuestaSim prompt: do scripts/questa/run_sync_system_top.do
# ============================================================================

vlib work
vmap work work

echo "=========================================="
echo "Compiling SI-CLASH Synchronizer RTL & TB..."
echo "=========================================="

vlog +acc -sv \
  rtl/str/gardner_ted_estimator.sv \
  rtl/str/modulo_1_controller.sv \
  rtl/str/parabolic_farrow_interpolator.sv \
  rtl/str/pI_loop.sv \
  rtl/str/str_top.sv \
  rtl/coarse_cfo/complex_mult.sv \
  rtl/coarse_cfo/accumulator.sv \
  rtl/coarse_cfo/cordic_angle.sv \
  rtl/coarse_cfo/coarse_cfo_core.sv \
  rtl/coarse_cfo/coarse_cfo_axi_wrapper.sv \
  +incdir+rtl/derotator rtl/derotator/lut_rom.sv \
  +incdir+rtl/derotator rtl/derotator/quadrant_rotator.sv \
  +incdir+rtl/derotator rtl/derotator/input_pipeline.sv \
  +incdir+rtl/derotator rtl/derotator/complex_multiplier.sv \
  +incdir+rtl/derotator rtl/derotator/Freq_word.sv \
  +incdir+rtl/derotator rtl/derotator/NCO_accumulator.sv \
  +incdir+rtl/derotator rtl/derotator/derotator.sv \
  rtl/costas/slicer.sv \
  rtl/costas/phase_error.sv \
  rtl/costas/pi_filter.sv \
  rtl/costas/lock_detector.sv \
  rtl/costas/quad_check.sv \
  rtl/costas/costas_top.sv \
  rtl/costas/err_align.sv \
  rtl/top/burst_ctrl.sv \
  rtl/top/dft_mux.sv \
  rtl/top/sync_system_top.sv \
  tb/top/tb_sync_system_top.sv

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
