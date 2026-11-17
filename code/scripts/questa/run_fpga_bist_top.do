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
  code/rtl/str/gardner_ted_estimator.sv \
  code/rtl/str/modulo_1_controller.sv \
  code/rtl/str/parabolic_farrow_interpolator.sv \
  code/rtl/str/pI_loop.sv \
  code/rtl/str/str_top.sv \
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
  code/rtl/bist/bist_input_rom.sv \
  code/rtl/bist/bist_expected_rom.sv \
  code/rtl/bist/seven_seg_controller.sv \
  code/rtl/bist/fpga_bist_top.sv \
  code/tb/bist/tb_fpga_bist_top.sv

echo "=========================================="
echo "Running tb_fpga_bist_top in batch mode"
echo "=========================================="

vsim -c -voptargs=+acc work.tb_fpga_bist_top -do "run -all; quit -f"
