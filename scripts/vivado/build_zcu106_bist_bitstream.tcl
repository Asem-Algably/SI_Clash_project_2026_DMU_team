# ==============================================================================
# Vivado 1-Click Batch Build Script: ZCU106 Standalone Hardware BIST
# Project: SI-CLASH Real-Time Digital Synchronizer
# Target Device: AMD Xilinx ZCU106 (xczu7ev-ffvc1156-2-e)
# Top Module: fpga_bist_top
# Constraints: constraints/zcu106_bist.xdc
# Temporary build artifacts placed on D:/ to preserve C:/ drive capacity.
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_ROOT  [file normalize "$SCRIPT_DIR/../../.."]
set BUILD_DIR  "D:/Asem/vivado_projects/zcu106_bist_run"

file mkdir $BUILD_DIR
cd $BUILD_DIR

puts "======================================================================"
puts "  SI-CLASH HARDWARE BIST: 1-CLICK ZCU106 BATCH BUILD"
puts "  Project Root : $PROJ_ROOT"
puts "  Build Output : $BUILD_DIR"
puts "======================================================================"

# ------------------------------------------------------------------------------
# 1. Target Device Selection
# ------------------------------------------------------------------------------
set TARGET_PART "xczu7ev-ffvc1156-2-e"
set part_check [get_parts -quiet $TARGET_PART]
set IS_ZCU106_TARGET [expr {[llength $part_check] > 0}]
set CLK_PRIMITIVE 1

if {[llength $part_check] == 0} {
    puts "NOTE: Target part '$TARGET_PART' (ZCU106 UltraScale+) is not installed in local Vivado instance."
    # Graceful fallback for local evaluation / syntax verification
    set fallback_parts [get_parts -quiet *xc7vx485tffg1761-2*]
    if {[llength $fallback_parts] == 0} {
        set fallback_parts [get_parts -quiet *xc7k325tffg900-2*]
    }
    if {[llength $fallback_parts] > 0} {
        set TARGET_PART [lindex $fallback_parts 0]
        set CLK_PRIMITIVE 2
        puts "Falling back to installed high-performance evaluation part: $TARGET_PART"
    } else {
        set TARGET_PART [lindex [get_parts] 0]
        set CLK_PRIMITIVE 0
        puts "Falling back to default part: $TARGET_PART"
    }
} else {
    puts "Selected Target Part: $TARGET_PART (AMD ZCU106 Zynq UltraScale+)"
    set CLK_PRIMITIVE 1
}

# ------------------------------------------------------------------------------
# 2. Copy/Link Memory Initialization Files to Build Directory
# ------------------------------------------------------------------------------
file copy -force "$PROJ_ROOT/rtl/bist/bist_input_vec.mem" "$BUILD_DIR/bist_input_vec.mem"
file copy -force "$PROJ_ROOT/rtl/bist/bist_exp_vec.mem"   "$BUILD_DIR/bist_exp_vec.mem"

# ------------------------------------------------------------------------------
# 3. Read Design Sources (SystemVerilog)
# ------------------------------------------------------------------------------
read_verilog -sv [list \
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
    "$PROJ_ROOT/rtl/costas/lock_detector.sv" \
    "$PROJ_ROOT/rtl/costas/quad_check.sv" \
    "$PROJ_ROOT/rtl/costas/costas_top.sv" \
    "$PROJ_ROOT/rtl/costas/err_align.sv" \
    "$PROJ_ROOT/rtl/top/burst_ctrl.sv" \
    "$PROJ_ROOT/rtl/top/dft_mux.sv" \
    "$PROJ_ROOT/rtl/top/sync_system_top.sv" \
    "$PROJ_ROOT/rtl/bist/bist_input_rom.sv" \
    "$PROJ_ROOT/rtl/bist/bist_expected_rom.sv" \
    "$PROJ_ROOT/rtl/bist/seven_seg_controller.sv" \
    "$PROJ_ROOT/rtl/bist/fpga_bist_top.sv" \
]

set_property include_dirs [list "$PROJ_ROOT/rtl/derotator"] [current_fileset]

# ------------------------------------------------------------------------------
# 4. Check for Optional Physical XDC Constraints
# (Explicitly omitted for now per user instruction)
# ------------------------------------------------------------------------------
set xdc_file "$PROJ_ROOT/constraints/zcu106_bist.xdc"
if {$IS_ZCU106_TARGET && [file exists $xdc_file]} {
    puts "Reading ZCU106 board constraints: $xdc_file"
    read_xdc $xdc_file
} else {
    puts "NOTE: Applying in-memory synthesis clock constraints for target/fallback part: $TARGET_PART"
    set synth_clock_xdc "$BUILD_DIR/synth_clock.xdc"
    set fp [open $synth_clock_xdc "w"]
    puts $fp "create_clock -period 8.000 -name clk_125_p \[get_ports clk_125_p\]"
    puts $fp "set_false_path -from \[get_ports btn_sw14\]"
    puts $fp "set_false_path -to \[get_ports {gpio_led\[*\]}\]"
    puts $fp "set_false_path -to \[get_ports {pmod_seg_o\[*\] pmod_dp_o pmod_an_o\[*\]}\]"
    close $fp
    read_xdc $synth_clock_xdc
}

# ------------------------------------------------------------------------------
# 5. Synthesis (fpga_bist_top)
# ------------------------------------------------------------------------------
puts "----------------------------------------------------------------------"
puts "  RUNNING SYNTHESIS (fpga_bist_top targeting $TARGET_PART)"
puts "----------------------------------------------------------------------"

set ENABLE_DEBUG_CORES 0
if {[info exists ::env(ENABLE_BIST_DEBUG_CORES)] && $::env(ENABLE_BIST_DEBUG_CORES) == "1"} {
    set ENABLE_DEBUG_CORES 1
}

# Auto-instantiate Vivado debug cores if requested
if {$ENABLE_DEBUG_CORES} {
    puts "Generating auto-instantiated Vivado debug cores (VIO & ILA)..."
    create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_0
    set_property -dict [list \
        CONFIG.C_NUM_PROBE_IN {6} \
        CONFIG.C_PROBE_IN0_WIDTH {16} \
        CONFIG.C_PROBE_IN1_WIDTH {8} \
        CONFIG.C_PROBE_IN2_WIDTH {1} \
        CONFIG.C_PROBE_IN3_WIDTH {1} \
        CONFIG.C_PROBE_IN4_WIDTH {1} \
        CONFIG.C_PROBE_IN5_WIDTH {1} \
        CONFIG.C_NUM_PROBE_OUT {1} \
        CONFIG.C_PROBE_OUT0_WIDTH {1} \
    ] [get_ips vio_0]
    generate_target {instantiation_template synthesis} [get_ips vio_0]

    create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
    set_property -dict [list \
        CONFIG.C_NUM_OF_PROBES {8} \
        CONFIG.C_PROBE0_WIDTH {1} \
        CONFIG.C_PROBE1_WIDTH {16} \
        CONFIG.C_PROBE2_WIDTH {16} \
        CONFIG.C_PROBE3_WIDTH {16} \
        CONFIG.C_PROBE4_WIDTH {16} \
        CONFIG.C_PROBE5_WIDTH {1} \
        CONFIG.C_PROBE6_WIDTH {1} \
        CONFIG.C_PROBE7_WIDTH {4} \
        CONFIG.C_DATA_DEPTH {1024} \
    ] [get_ips ila_0]
    generate_target {instantiation_template synthesis} [get_ips ila_0]
}

set input_mem "$BUILD_DIR/bist_input_vec.mem"
set exp_mem   "$BUILD_DIR/bist_exp_vec.mem"

# In out-of-context or unconstrained mode, pass parameters for target clock primitive and files
synth_design -top fpga_bist_top -part $TARGET_PART \
    -generic "CLK_GEN_PRIMITIVE=$CLK_PRIMITIVE" \
    -generic "INPUT_ROM_FILE=$input_mem" \
    -generic "EXP_ROM_FILE=$exp_mem" \
    -generic "ENABLE_DEBUG_CORES=$ENABLE_DEBUG_CORES" \
    -mode out_of_context

# Re-apply clock constraint in case not propagated through OOC
create_clock -period 8.000 -name clk_125_p [get_ports clk_125_p] -quiet

write_checkpoint -force "$BUILD_DIR/post_synth.dcp"
report_utilization -file "$BUILD_DIR/post_synth_utilization.rpt"
report_timing_summary -file "$BUILD_DIR/post_synth_timing.rpt"

set wns [get_property SLACK [get_timing_paths -max_paths 1 -quiet]]
puts "======================================================================"
puts "  SYNTHESIS TIMING SUMMARY"
puts "  Worst Negative Slack (WNS): $wns ns"
puts "======================================================================"

# ------------------------------------------------------------------------------
# 6. Implementation & Bitstream Check
# ------------------------------------------------------------------------------
if {[file exists $xdc_file]} {
    puts "----------------------------------------------------------------------"
    puts "  RUNNING IMPLEMENTATION & BITSTREAM GENERATION"
    puts "----------------------------------------------------------------------"
    opt_design
    place_design
    phys_opt_design
    route_design
    write_checkpoint -force "$BUILD_DIR/post_route.dcp"

    # Exhaustive System & Implementation Reports
    puts "Dumping Post-Route Implementation Reports..."
    report_timing_summary -file "$BUILD_DIR/post_route_timing.rpt" -max_paths 10 -warn_on_violation
    report_timing -nworst 10 -max_paths 50 -file "$BUILD_DIR/post_route_worst_paths.rpt"
    report_power -file "$BUILD_DIR/post_route_power.rpt" -xpe "$BUILD_DIR/post_route_power.xpe"
    report_utilization -file "$BUILD_DIR/post_route_utilization.rpt"
    report_utilization -hierarchical -file "$BUILD_DIR/post_route_utilization_hierarchical.rpt"
    report_drc -file "$BUILD_DIR/post_route_drc.rpt"
    report_methodology -file "$BUILD_DIR/post_route_methodology.rpt"

    if {$IS_ZCU106_TARGET} {
        write_bitstream -force "$BUILD_DIR/fpga_bist_top.bit"
        puts "SUCCESS: Generated $BUILD_DIR/fpga_bist_top.bit!"
    } else {
        puts "NOTE: Bitstream generation for physical FPGA requires ZCU106 UltraScale+ device files."
    }
} else {
    puts "NOTE: Physical XDC pin constraints file not found at: $xdc_file"
}

puts "======================================================================"
puts "  BATCH BUILD COMPLETED SUCCESSFULLY"
puts "======================================================================"
