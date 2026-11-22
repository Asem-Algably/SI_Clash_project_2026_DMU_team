# ==============================================================================
# Timing Constraints for SI-CLASH Digital Synchronizer Top (200 MHz)
# Target Frequency: 200.00 MHz
# Clock Period:     5.000 ns (50% duty cycle: 0.000 rising, 2.500 falling)
# ==============================================================================

create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]

# Set false paths for purely static DFT/configuration control ports (if needed)
set_false_path -through [get_ports {mod_type* loop_gain* costas_loop_gain* dft_sel* force_*}]
