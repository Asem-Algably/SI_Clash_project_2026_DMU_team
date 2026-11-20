# ============================================================================
# QuestaSim Master Simulation Script: 5 Subsystems & Top Integration
# Project: SI-CLASH Real-Time Digital Synchronizer
# Usage:   vsim -c -do "do code/scripts/questa/run_all_subsystem_sims.do; quit -f"
# ============================================================================

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

echo "======================================================================"
echo "  COMPILING SI-CLASH RTL MODULES"
echo "======================================================================"

vlog +acc +cover=bcestf -sv \
  code/rtl/costas/lock_detector.sv \
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
  code/rtl/costas/quad_check.sv \
  code/rtl/costas/costas_top.sv \
  code/rtl/costas/err_align.sv \
  code/rtl/top/burst_ctrl.sv \
  code/rtl/top/dft_mux.sv \
  code/rtl/top/sync_system_top.sv

echo "======================================================================"
echo "  COMPILING TESTBENCHES & OPTIMIZING DESIGN UNITS"
echo "======================================================================"

vlog +acc -sv \
  code/tb/str/tb_str_top.sv \
  code/tb/coarse_cfo/tb_coarse_cfo_core.sv \
  code/tb/derotator/derotator_pkg.sv \
  code/tb/derotator/tb_derotator.sv \
  code/tb/costas/costas_pkg.sv \
  code/tb/costas/tb_costas_top.sv \
  code/tb/top/tb_sync_system_top.sv

echo "======================================================================"
echo "  PRE-OPTIMIZING DESIGN UNITS"
echo "======================================================================"

vopt +acc +cover=bcestf work.tb_str_top -o opt_str
vopt +acc +cover=bcestf work.tb_coarse_cfo_core -o opt_coarse
vopt +acc +cover=bcestf work.tb_derotator -o opt_derot
vopt +acc +cover=bcestf work.tb_costas_top -o opt_costas
vopt +acc +cover=bcestf work.tb_sync_system_top -o opt_top

echo "======================================================================"
echo "  (1/5) RUNNING STR TESTBENCH (tb_str_top)"
echo "======================================================================"
vsim -coverage opt_str
run -all
coverage save cov_str.ucdb
quit -sim

echo "======================================================================"
echo "  (2/5) RUNNING COARSE CFO TESTBENCH (tb_coarse_cfo_core)"
echo "======================================================================"
vsim -coverage opt_coarse
run -all
coverage save cov_coarse.ucdb
quit -sim

echo "======================================================================"
echo "  (3/5) RUNNING DEROTATOR TESTBENCH (tb_derotator)"
echo "======================================================================"
vsim -coverage opt_derot
run -all
coverage save cov_derot.ucdb
quit -sim

echo "======================================================================"
echo "  (4/5) RUNNING COSTAS LOOP TESTBENCH (tb_costas_top)"
echo "======================================================================"
vsim -coverage opt_costas
run -all
coverage save cov_costas.ucdb
quit -sim

echo "======================================================================"
echo "  (5/5) RUNNING TOP SYSTEM TESTBENCH (tb_sync_system_top)"
echo "======================================================================"
vsim -coverage opt_top
run -all
coverage save cov_top.ucdb
quit -sim

echo "======================================================================"
echo "  GENERATING MERGED COVERAGE REPORT"
echo "======================================================================"
vcover merge total_cov.ucdb cov_str.ucdb cov_coarse.ucdb cov_derot.ucdb cov_costas.ucdb cov_top.ucdb
vcover report -details -output coverage_report.txt total_cov.ucdb
vcover report -html -htmldir cov_html_report total_cov.ucdb

echo "======================================================================"
echo "  ALL SUB-SYSTEM VERIFICATION SIMULATIONS COMPLETED"
echo "======================================================================"
vcover report -codeAll -details -output coverage_report.txt total_cov.ucdb
vcover report -codeAll -html -htmldir cov_html_report total_cov.ucdb
