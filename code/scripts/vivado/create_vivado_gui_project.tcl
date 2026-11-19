# ==============================================================================
# Script: create_vivado_gui_project.tcl
# Purpose: Automatically creates the complete Vivado GUI Project (.xpr)
#          so you can open it in the Vivado GUI and use buttons.
# Output Project: D:/Asem/vivado_projects/rx_sync_zcu106/rx_sync_zcu106.xpr
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_ROOT  [file normalize "$SCRIPT_DIR/../../.."]
set PROJ_DIR   "D:/Asem/vivado_projects/rx_sync_zcu106"
set PROJ_NAME  "rx_sync_zcu106"

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
        puts "INFO: ZCU106 silicon part not yet installed. Setting project part to installed evaluation part: $TARGET_PART"
    }
} else {
    puts "INFO: Setting project target to AMD ZCU106 ($TARGET_PART)"
}

# 3. Create the Vivado .xpr Project
create_project $PROJ_NAME $PROJ_DIR -part $TARGET_PART -force

# Target board setting
catch { set_property board_part xilinx.com:zcu106:part0:2.4 [current_project] }

# 4. Add all SystemVerilog Source Files
add_files -fileset sources_1 [list \
    "$PROJ_ROOT/code/rtl/str/gardner_ted_estimator.sv" \
    "$PROJ_ROOT/code/rtl/str/modulo_1_controller.sv" \
    "$PROJ_ROOT/code/rtl/str/parabolic_farrow_interpolator.sv" \
    "$PROJ_ROOT/code/rtl/str/pI_loop.sv" \
    "$PROJ_ROOT/code/rtl/str/str_top.sv" \
    "$PROJ_ROOT/code/rtl/coarse_cfo/complex_mult.sv" \
    "$PROJ_ROOT/code/rtl/coarse_cfo/accumulator.sv" \
    "$PROJ_ROOT/code/rtl/coarse_cfo/cordic_angle.sv" \
    "$PROJ_ROOT/code/rtl/coarse_cfo/coarse_cfo_core.sv" \
    "$PROJ_ROOT/code/rtl/coarse_cfo/coarse_cfo_axi_wrapper.sv" \
    "$PROJ_ROOT/code/rtl/derotator/lut_rom.sv" \
    "$PROJ_ROOT/code/rtl/derotator/quadrant_rotator.sv" \
    "$PROJ_ROOT/code/rtl/derotator/input_pipeline.sv" \
    "$PROJ_ROOT/code/rtl/derotator/complex_multiplier.sv" \
    "$PROJ_ROOT/code/rtl/derotator/Freq_word.sv" \
    "$PROJ_ROOT/code/rtl/derotator/NCO_accumulator.sv" \
    "$PROJ_ROOT/code/rtl/derotator/derotator.sv" \
    "$PROJ_ROOT/code/rtl/costas/slicer.sv" \
    "$PROJ_ROOT/code/rtl/costas/phase_error.sv" \
    "$PROJ_ROOT/code/rtl/costas/pi_filter.sv" \
    "$PROJ_ROOT/code/rtl/costas/lock_detector.sv" \
    "$PROJ_ROOT/code/rtl/costas/quad_check.sv" \
    "$PROJ_ROOT/code/rtl/costas/costas_top.sv" \
    "$PROJ_ROOT/code/rtl/costas/err_align.sv" \
    "$PROJ_ROOT/code/rtl/top/burst_ctrl.sv" \
    "$PROJ_ROOT/code/rtl/top/dft_mux.sv" \
    "$PROJ_ROOT/code/rtl/top/sync_system_top.sv" \
    "$PROJ_ROOT/code/rtl/bist/bist_input_rom.sv" \
    "$PROJ_ROOT/code/rtl/bist/bist_expected_rom.sv" \
    "$PROJ_ROOT/code/rtl/bist/seven_seg_controller.sv" \
    "$PROJ_ROOT/code/rtl/bist/fpga_bist_top.sv" \
]

# 5. Add Memory Vector Files (.mem)
add_files -fileset sources_1 [list \
    "$PROJ_ROOT/code/rtl/bist/bist_input_vec.mem" \
    "$PROJ_ROOT/code/rtl/bist/bist_exp_vec.mem" \
]

# 6. Add Constraints File (.xdc)
add_files -fileset constrs_1 [list \
    "$PROJ_ROOT/code/constraints/zcu106_bist.xdc" \
]

# 7. Configure include directories and top module
set_property include_dirs [list "$PROJ_ROOT/code/rtl/derotator"] [current_fileset]
set_property top fpga_bist_top [current_fileset]
update_compile_order -fileset sources_1

puts "======================================================================"
puts "SUCCESS: Project created at $PROJ_DIR/$PROJ_NAME.xpr"
puts "You can now open this project directly in Vivado GUI!"
puts "======================================================================"
