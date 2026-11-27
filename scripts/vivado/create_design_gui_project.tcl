# ==============================================================================
# Script: create_design_gui_project.tcl
# Purpose: Creates a Vivado GUI Project (.xpr) for the core synchronizer design
#          ONLY (top: sync_system_top), excluding all BIST wrapper/ROM logic.
# Output Project: D:/Asem/vivado_projects/rx_sync_design_only/rx_sync_design_only.xpr
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_ROOT  [file normalize "$SCRIPT_DIR/../.."]
set PROJ_DIR   "D:/Asem/vivado_projects/rx_sync_design_only"
set PROJ_NAME  "rx_sync_design_only"

# 1. Create project directory
file mkdir $PROJ_DIR

# 2. Select Target Part (ZCU106 UltraScale+ or installed fallback)
set TARGET_PART "xczu7ev-ffvc1156-2-e"
set part_check [get_parts -quiet $TARGET_PART]
if {[llength $part_check] == 0} {
    set fallback [get_parts -quiet *xc7vx485tffg1761-2*]
    if {[llength $fallback] == 0} { set fallback [get_parts -quiet *xc7k325tffg900-2*] }
    if {[llength $fallback] > 0} {
        set TARGET_PART [lindex $fallback 0]
        puts "INFO: ZCU106 silicon part not installed. Using fallback part: $TARGET_PART"
    }
} else {
    puts "INFO: Setting project target to AMD ZCU106 ($TARGET_PART)"
}

# 3. Create the Vivado .xpr Project
create_project $PROJ_NAME $PROJ_DIR -part $TARGET_PART -force

# 4. Add Design-Only SystemVerilog RTL Source Files (NO rtl/bist/*)
add_files -fileset sources_1 [list \
    "$PROJ_ROOT/rtl/str/gardner_ted_estimator.sv" \
    "$PROJ_ROOT/rtl/str/modulo_1_controller.sv" \
    "$PROJ_ROOT/rtl/str/parabolic_farrow_interpolator.sv" \
    "$PROJ_ROOT/rtl/str/pI_loop.sv" \
    "$PROJ_ROOT/rtl/str/str_top.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/complex_mult.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/accumulator.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/cordic_angle.sv" \
    "$PROJ_ROOT/rtl/coarse_cfo/coarse_cfo_core.sv" \
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
]

# 5. Add Design-Only 200 MHz Clock & False-Path Constraints (.xdc)
add_files -fileset constrs_1 [list \
    "$PROJ_ROOT/scripts/vivado/timing_200mhz.xdc" \
]

# 6. Add Design-Only Simulation Testbench (.sv) and vector file for xsim
add_files -fileset sim_1 [list \
    "$PROJ_ROOT/tb/top/tb_sync_system_top.sv" \
]

set sim_vec_dir "$PROJ_DIR/$PROJ_NAME.sim/sim_1/behav/xsim/tb/vectors"
file mkdir $sim_vec_dir
if {[file exists "$PROJ_ROOT/tb/vectors/tb_top_vec.hex"]} {
    file copy -force "$PROJ_ROOT/tb/vectors/tb_top_vec.hex" "$sim_vec_dir/tb_top_vec.hex"
}

# 7. Configure include directories, synthesis top (Out-of-Context for raw IP pins), and sim top
set_property include_dirs [list "$PROJ_ROOT/rtl/derotator"] [current_fileset]
set_property top sync_system_top [current_fileset]
update_compile_order -fileset sources_1

# Out-of-Context synthesis avoids inserting 225 package IOBs on internal IP ports
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

set_property top tb_sync_system_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "======================================================================"
puts "SUCCESS: Design-only project created at $PROJ_DIR/$PROJ_NAME.xpr"
puts "Top Module: sync_system_top (Out-of-Context @ 200 MHz, no BIST)"
puts "You can open this project in Vivado GUI or run generate_design_reports.tcl."
puts "======================================================================"
