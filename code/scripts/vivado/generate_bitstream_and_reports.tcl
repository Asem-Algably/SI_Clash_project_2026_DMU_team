# ==============================================================================
# Script: generate_bitstream_and_reports.tcl
# Description: Fully automated script to run Implementation, generate the
#              FPGA Bitstream (.bit + .ltx), and export complete professional
#              Timing, Utilization, Power, and DRC reports.
# ==============================================================================

set SCRIPT_DIR  [file normalize [file dirname [info script]]]
set PROJ_ROOT   [file normalize "$SCRIPT_DIR/../../.."]
set REPORT_DIR  "$PROJ_ROOT/reports/fpga_implementation"
file mkdir $REPORT_DIR

# 1. Ensure max 2 threads so it runs safely inside your 8 GB RAM budget
set_param general.maxThreads 2

puts "======================================================================"
puts "  STARTING AUTOMATED FPGA IMPLEMENTATION & BITSTREAM GENERATION"
puts "======================================================================"

# 2. Check current project status
if {[current_project -quiet] == ""} {
    set PROJ_FILE "D:/Asem/vivado_projects/rx_sync_zcu106/rx_sync_zcu106.xpr"
    if {[file exists $PROJ_FILE]} {
        puts "INFO: Opening project: $PROJ_FILE"
        open_project $PROJ_FILE
    } else {
        puts "ERROR: Cannot find project at $PROJ_FILE"
        return
    }
}

# 3. Check if synthesis needs to run or re-run
set synth_run [get_runs synth_1]
if {[get_property NEEDS_REFRESH $synth_run] || [get_property STATUS $synth_run] == "Not Started"} {
    puts "INFO: Running Synthesis (synth_1)..."
    reset_run synth_1
    launch_runs synth_1 -jobs 2
    wait_on_run synth_1
    if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
        puts "ERROR: Synthesis failed! Please check synth_1 log."
        return
    }
} else {
    puts "INFO: Synthesis is already up-to-date."
}

# 4. Run Implementation & Bitstream Generation
puts "INFO: Launching Implementation through Bitstream Generation (impl_1)..."
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "INFO: Implementation finished with status: $impl_status"

if {$impl_status != "write_bitstream Complete!" && $impl_status != "route_design Complete!"} {
    puts "ERROR: Implementation/Bitstream did not complete successfully. Check impl_1 run log."
    return
}

# 5. Open Implemented Design to Extract Detailed Reports
puts "INFO: Opening Implemented Design for Report Generation..."
open_run impl_1

# 6. Generate Comprehensive Reports
puts "INFO: Writing Utilization Reports..."
report_utilization -file "$REPORT_DIR/utilization_summary.rpt"
report_utilization -hierarchical -file "$REPORT_DIR/utilization_hierarchical.rpt"

puts "INFO: Writing Timing Reports..."
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file "$REPORT_DIR/timing_summary.rpt"
report_clock_utilization -file "$REPORT_DIR/clock_utilization.rpt"

puts "INFO: Writing Power Report..."
report_power -file "$REPORT_DIR/power_analysis.rpt"

puts "INFO: Writing DRC Report..."
report_drc -file "$REPORT_DIR/drc_report.rpt"

# 7. Copy Bitstream and Probes to the Project Reports Directory for easy access
set IMPL_DIR [get_property DIRECTORY [get_runs impl_1]]
set BIT_FILE "$IMPL_DIR/fpga_bist_top.bit"
set LTX_FILE "$IMPL_DIR/fpga_bist_top.ltx"

if {[file exists $BIT_FILE]} {
    file copy -force $BIT_FILE "$REPORT_DIR/fpga_bist_top.bit"
    puts "SUCCESS: Bitstream copied to: $REPORT_DIR/fpga_bist_top.bit"
}
if {[file exists $LTX_FILE]} {
    file copy -force $LTX_FILE "$REPORT_DIR/fpga_bist_top.ltx"
    puts "SUCCESS: Debug Probes copied to: $REPORT_DIR/fpga_bist_top.ltx"
}

# 8. Print Executive Summary in Tcl Console
set wns [get_property STATS.WNS [get_runs impl_1]]
set tns [get_property STATS.TNS [get_runs impl_1]]

puts "======================================================================"
puts "  IMPLEMENTATION & BITSTREAM GENERATION COMPLETE!"
puts "======================================================================"
puts "  Target Device : xczu7ev-ffvc1156-2-e (ZCU106)"
puts "  Worst Neg Slack (WNS) : $wns ns"
puts "  Total Neg Slack (TNS) : $tns ns"
puts "  Reports Directory     : $REPORT_DIR"
puts "  Bitstream Location    : $REPORT_DIR/fpga_bist_top.bit"
puts "======================================================================"
