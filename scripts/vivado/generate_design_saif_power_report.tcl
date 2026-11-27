# ==============================================================================
# Script: generate_design_saif_power_report.tcl
# Description: Captures switching activity (.saif & .vcd) from tb_sync_system_top
#              (design-only, no BIST) and annotates the routed sync_system_top
#              design to export vector-driven power reports.
# ==============================================================================

set SCRIPT_DIR  [file normalize [file dirname [info script]]]
set PROJ_ROOT   [file normalize "$SCRIPT_DIR/../.."]
set REPORT_DIR  "$PROJ_ROOT/reports/fpga_design_only"
file mkdir $REPORT_DIR

if {[current_project -quiet] == ""} {
    set PROJ_FILE "D:/Asem/vivado_projects/zcu106_fpga_flow/rx_sync_design_only.xpr"
    if {[file exists $PROJ_FILE]} {
        open_project $PROJ_FILE
    } else {
        puts "ERROR: Project not found at $PROJ_FILE. Run create_design_gui_project.tcl first."
        return
    }
}

set PROJ_DIR    [get_property DIRECTORY [current_project]]
set PROJ_NAME   [get_property NAME [current_project]]
set sim_vec_dir "$PROJ_DIR/$PROJ_NAME.sim/sim_1/behav/xsim/tb/vectors"
file mkdir $sim_vec_dir
if {[file exists "$PROJ_ROOT/tb/vectors/tb_top_vec.hex"]} {
    file copy -force "$PROJ_ROOT/tb/vectors/tb_top_vec.hex" "$sim_vec_dir/tb_top_vec.hex"
}

set SAIF_FILE "$REPORT_DIR/switching_activity_design.saif"
set VCD_FILE  "$REPORT_DIR/switching_activity_design.vcd"
set POWER_RPT "$REPORT_DIR/power_dynamic_leakage_saif.rpt"
set POWER_XPE "$REPORT_DIR/power_characterization_saif.xpe"

puts "======================================================================"
puts "  STEP 1: CAPTURING DESIGN-ONLY SWITCHING ACTIVITY (.saif & .vcd)"
puts "======================================================================"

if {[current_sim -quiet] == ""} {
    launch_simulation
}

restart
catch { close_saif }
catch { close_vcd }

open_saif $SAIF_FILE
log_saif [get_objects -r /tb_sync_system_top/dut/*]

open_vcd $VCD_FILE
log_vcd [get_objects -r /tb_sync_system_top/dut/*]

run 35 us

close_saif
close_vcd

puts "======================================================================"
puts "  STEP 2: ANNOTATING DESIGN-ONLY SAIF INTO ROUTED IMPLEMENTATION"
puts "======================================================================"

if {[current_design -quiet] == ""} {
    set impl_run [get_runs -quiet impl_1]
    set impl_status [expr {$impl_run != "" ? [get_property STATUS $impl_run] : ""}]
    if {$impl_status == "route_design Complete!"} {
        open_run impl_1
    } else {
        open_run synth_1
    }
}

if {[current_design -quiet] == ""} {
    puts "ERROR: No synthesized or implemented design available for SAIF power report."
    return
}

catch { read_saif -strip_path tb_sync_system_top/dut $SAIF_FILE }
report_power -file $POWER_RPT -xpe $POWER_XPE

puts "======================================================================"
puts "  DESIGN-ONLY SAIF POWER CHARACTERIZATION COMPLETE!"
puts "  Report : $POWER_RPT"
puts "======================================================================"
