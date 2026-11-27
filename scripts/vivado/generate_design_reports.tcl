# ==============================================================================
# Script: generate_design_reports.tcl
# Description: Runs Synthesis and Routed Implementation for the core design ONLY
#              (top: sync_system_top, Out-of-Context @ 200 MHz, without BIST)
#              and exports Utilization, Timing, Power, Clock, and DRC reports.
# ==============================================================================

set SCRIPT_DIR  [file normalize [file dirname [info script]]]
set PROJ_ROOT   [file normalize "$SCRIPT_DIR/../.."]
set REPORT_DIR  "$PROJ_ROOT/reports/fpga_design_only"
file mkdir $REPORT_DIR

# Keep within 8 GB RAM budget
set_param general.maxThreads 2

puts "======================================================================"
puts "  STARTING DESIGN-ONLY FPGA SYNTHESIS, IMPLEMENTATION & REPORTS"
puts "  Top Module : sync_system_top (No BIST)"
puts "======================================================================"

# 1. Open project if not already open in Vivado GUI
if {[current_project -quiet] == ""} {
    set PROJ_FILE "D:/Asem/vivado_projects/zcu106_fpga_flow/rx_sync_design_only.xpr"
    if {[file exists $PROJ_FILE]} {
        puts "INFO: Opening project: $PROJ_FILE"
        open_project $PROJ_FILE
    } else {
        puts "ERROR: Cannot find project at $PROJ_FILE"
        puts "       Run create_design_gui_project.tcl first."
        return
    }
}

# 2. Run Synthesis (synth_1)
puts "INFO: Running Out-of-Context Synthesis (synth_1)..."
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed! Check synth_1 runme.log."
    return
}

# 3. Run Implementation through route_design (impl_1)
puts "INFO: Launching Place & Route Implementation (impl_1)..."
reset_run impl_1
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "INFO: Implementation finished with status: $impl_status"
if {$impl_status != "route_design Complete!"} {
    puts "ERROR: Implementation did not reach route_design Complete! Check impl_1 runme.log."
    return
}

# 4. Open Routed Design and Export Design-Only Reports
puts "INFO: Opening Routed Design (impl_1) for report export..."
open_run impl_1

puts "INFO: Writing Utilization Reports..."
report_utilization -file "$REPORT_DIR/utilization_summary.rpt"
report_utilization -hierarchical -file "$REPORT_DIR/utilization_hierarchical.rpt"

puts "INFO: Writing Timing Reports..."
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file "$REPORT_DIR/timing_summary.rpt"
report_timing -max_paths 10 -nworst 1 -input_pins -routable_nets -file "$REPORT_DIR/worst_timing_paths.rpt"
report_clock_utilization -file "$REPORT_DIR/clock_utilization.rpt"

puts "INFO: Writing Power Report (vectorless baseline)..."
report_power -file "$REPORT_DIR/power_analysis.rpt" -xpe "$REPORT_DIR/power_analysis.xpe"

puts "INFO: Writing DRC Report..."
report_drc -file "$REPORT_DIR/drc_report.rpt"

# 5. Executive Console Summary
set wns [get_property STATS.WNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
set tns [get_property STATS.TNS [get_runs impl_1]]

puts "======================================================================"
puts "  DESIGN-ONLY FPGA IMPLEMENTATION & REPORT EXPORT COMPLETE!"
puts "======================================================================"
puts "  Top Module            : sync_system_top (No BIST)"
puts "  Target Device         : [get_property PART [current_project]]"
puts "  Worst Setup Slack WNS : $wns ns"
puts "  Total Neg Slack   TNS : $tns ns"
puts "  Worst Hold Slack  WHS : $whs ns"
puts "  Reports Directory     : $REPORT_DIR"
puts "======================================================================"
