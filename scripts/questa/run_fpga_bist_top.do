# ============================================================================
# QuestaSim Simulation Automation Script for FPGA BIST Wrapper
# Project: SI-CLASH Real-Time Digital Synchronizer (ZCU106 BIST)
# ============================================================================

onerror {quit -f}

vlib work
vmap work work

echo "=========================================="
echo "Compiling SI-CLASH Synchronizer & BIST RTL..."
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
  rtl/bist/bist_input_rom.sv \
  rtl/bist/bist_expected_rom.sv \
  rtl/bist/seven_seg_controller.sv \
  rtl/bist/fpga_bist_top.sv \
  tb/bist/tb_fpga_bist_top.sv

echo "=========================================="
echo "Running tb_fpga_bist_top in batch mode"
echo "=========================================="

vsim -c -voptargs=+acc work.tb_fpga_bist_top -do "run -all; quit -f"
