# ==============================================================================
# Vivado Synthesis & Implementation Script - 200 MHz Timing Closure
# Project: SI-CLASH Real-Time Digital Synchronizer
# Target Clock: 200 MHz (Period = 5.000 ns)
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_ROOT  [file normalize "$SCRIPT_DIR/../../.."]
set BUILD_DIR  "D:/Asem/vivado_projects/si_clash_sync_run"

file mkdir $BUILD_DIR
cd $BUILD_DIR

puts "======================================================================"
puts "  SI-CLASH DIGITAL SYNCHRONIZER: VIVADO 200 MHz IMPLEMENTATION"
puts "  Project Root : $PROJ_ROOT"
puts "  Build Output : $BUILD_DIR"
puts "======================================================================"

# Target Part Selection:
# The user specified: Xilinx Zynq UltraScale+ FPGA Evaluation Kit (e.g. ZCU102 -> xczu9eg-ffvb1156-2-e)
# If UltraScale+ is not installed in the local Vivado instance, fall back to high-performance Kintex-7/Virtex-7.
set TARGET_PART "xczu9eg-ffvb1156-2-e"
set part_check [get_parts -quiet $TARGET_PART]

if {[llength $part_check] == 0} {
    puts "NOTE: Target part '$TARGET_PART' (Zynq UltraScale+) is not installed in this Vivado instance."
    # Find best available evaluation kit part (KC705 / VC707 speed-grade -2)
    set fallback_parts [get_parts *xc7k325tffg900-2*]
    if {[llength $fallback_parts] == 0} {
        set fallback_parts [get_parts *xc7vx485tffg1761-2*]
    }
    if {[llength $fallback_parts] > 0} {
        set TARGET_PART [lindex $fallback_parts 0]
        puts "Falling back to Evaluation Kit part: $TARGET_PART"
    } else {
        set TARGET_PART [lindex [get_parts] 0]
        puts "Falling back to: $TARGET_PART"
    }
} else {
    puts "Selected Target Part: $TARGET_PART (Zynq UltraScale+)"
}

# ------------------------------------------------------------------------------
# 1. Read Design Sources (SystemVerilog)
# ------------------------------------------------------------------------------
read_verilog -sv [list \
    "$PROJ_ROOT/rtl/costas/lock_detector.sv" \
    "$PROJ_ROOT/rtl/str/gardner_ted_estimator.sv" \
    "$PROJ_ROOT/rtl/str/modulo_1_controller.sv" \
    "$PROJ_ROOT/rtl/str/parabolic_farrow_interpolator.sv" \
    "$PROJ_ROOT/rtl/str/pI_loop.sv" \
    "$PROJ_ROOT/rtl/str/str_top.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/complex_mult.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/accumulator.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/cordic_angle.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/coarse_cfo_core.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/coarse_cfo_axi_wrapper.sv" \
    "$PROJ_ROOT/rtl/derotator/lut_rom.sv" \
    "$PROJ_ROOT/rtl/derotator/quadrant_rotator.sv" \
    "$PROJ_ROOT/rtl/derotator/input_pipeline.sv" \
    "$PROJ_ROOT/rtl/derotator/complex_multiplier.sv" \
    "$PROJ_ROOT/rtl/derotator/Freq_word.sv" \
    "$PROJ_ROOT/rtl/derotator/NCO_accumulator.sv" \
    "$PROJ_ROOT/rtl/derotator/derotator.sv" \
    "$PROJ_ROOT/rtl/costas/slicer.sv" \
    "$PROJ_ROOT/rtl/costas/phase_error.sv" \
    "$PROJ_ROOT/rtl/costas/pi_filter.sv" \
    "$PROJ_ROOT/rtl/costas/quad_check.sv" \
    "$PROJ_ROOT/rtl/costas/costas_top.sv" \
    "$PROJ_ROOT/rtl/costas/err_align.sv" \
    "$PROJ_ROOT/rtl/top/burst_ctrl.sv" \
    "$PROJ_ROOT/rtl/top/dft_mux.sv" \
    "$PROJ_ROOT/rtl/top/sync_system_top.sv" \
]

# Set Include Directory for lut_rom.sv
set_property include_dirs [list "$PROJ_ROOT/rtl/derotator"] [current_fileset]

# ------------------------------------------------------------------------------
# 2. Constraints (200 MHz Clock = 5.000 ns Period)
# ------------------------------------------------------------------------------
read_xdc [list "$PROJ_ROOT/scripts/vivado/timing_200mhz.xdc"]

# ------------------------------------------------------------------------------
# 3. Out-Of-Context Synthesis
# ------------------------------------------------------------------------------
puts "----------------------------------------------------------------------"
puts "  RUNNING SYNTHESIS (sync_system_top @ 200 MHz)"
puts "----------------------------------------------------------------------"
synth_design -top sync_system_top -part $TARGET_PART -mode out_of_context

write_checkpoint -force "$BUILD_DIR/post_synth.dcp"
report_utilization -file "$BUILD_DIR/post_synth_utilization.rpt"
report_timing_summary -file "$BUILD_DIR/post_synth_timing.rpt"

# ------------------------------------------------------------------------------
# 4. Optimization & Placement
# ------------------------------------------------------------------------------
puts "----------------------------------------------------------------------"
puts "  RUNNING OPTIMIZATION & PLACEMENT"
puts "----------------------------------------------------------------------"
opt_design
place_design
phys_opt_design

write_checkpoint -force "$BUILD_DIR/post_place.dcp"

# ------------------------------------------------------------------------------
# 5. Routing & Final Timing Analysis
# ------------------------------------------------------------------------------
puts "----------------------------------------------------------------------"
puts "  RUNNING ROUTING & FINAL TIMING ANALYSIS"
puts "----------------------------------------------------------------------"
route_design

write_checkpoint -force "$BUILD_DIR/post_route.dcp"
report_utilization -file "$BUILD_DIR/post_route_utilization.rpt"
report_timing_summary -file "$BUILD_DIR/post_route_timing.rpt"
report_timing -max_paths 10 -nworst 1 -file "$BUILD_DIR/worst_paths.rpt"

# ------------------------------------------------------------------------------
# 6. Parse and Display Timing Status
# ------------------------------------------------------------------------------
set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -hold]]

puts "======================================================================"
puts "  FINAL TIMING CLOSURE SUMMARY (Target: 200.00 MHz / 5.000 ns)"
puts "  Worst Negative Slack (WNS) Setup: $wns ns"
puts "  Worst Hold Slack     (WHS) Hold : $whs ns"
if {$wns >= 0.0} {
    puts "  >>> TIMING MET: 200 MHz FREQUENCY ACHIEVED! <<<"
} else {
    puts "  >>> TIMING VIOLATED: Slack = $wns ns <<<"
}
puts "======================================================================"
