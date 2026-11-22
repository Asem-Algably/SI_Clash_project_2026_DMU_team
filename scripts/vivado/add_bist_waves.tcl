# ==============================================================================
# Script: add_bist_waves.tcl (CLEAN DEMONSTRATION SETUP)
# ==============================================================================

# 1. Clock & Reset Control
add_wave_divider "CLOCK & RESET"
add_wave -name "System Clock (200MHz)" /tb_fpga_bist_top/clk_125_p
add_wave -name "Reset Button SW14"     /tb_fpga_bist_top/btn_sw14

# 2. Raw Receiver Baseband Input (Distorted IQ Stream)
add_wave_divider "RAW RECEIVER IQ INPUT"
add_wave -radix dec -name "Raw Input I" /tb_fpga_bist_top/dut_in_i
add_wave -radix dec -name "Raw Input Q" /tb_fpga_bist_top/dut_in_q
catch {
  set_property waveform_style analog [get_waves /tb_fpga_bist_top/dut_in_i]
  set_property waveform_style analog [get_waves /tb_fpga_bist_top/dut_in_q]
}

# 3. Demodulated Output vs Golden Reference (Proof of Synchronization)
add_wave_divider "DEMODULATED SYMBOLS VS GOLDEN"
add_wave -name "Symbol Valid Strobe"                   /tb_fpga_bist_top/sym_valid
add_wave -radix dec -name "Recovered I Symbol"         /tb_fpga_bist_top/sym_out_i
add_wave -radix dec -name "Golden Exp I Symbol"        /tb_fpga_bist_top/sym_exp_i
add_wave -radix dec -name "Recovered Q Symbol"         /tb_fpga_bist_top/sym_out_q
add_wave -radix dec -name "Golden Exp Q Symbol"        /tb_fpga_bist_top/sym_exp_q
catch {
  set_property waveform_style analog [get_waves /tb_fpga_bist_top/sym_out_i]
  set_property waveform_style analog [get_waves /tb_fpga_bist_top/sym_exp_i]
  set_property waveform_style analog [get_waves /tb_fpga_bist_top/sym_out_q]
  set_property waveform_style analog [get_waves /tb_fpga_bist_top/sym_exp_q]
}
add_wave -color green -name "Bit-Exact Match (1=Match)" /tb_fpga_bist_top/sym_match

# 4. Hardware Outputs & 7-Segment Display (Proof of Test Completion)
add_wave_divider "BOARD OUTPUTS & 7-SEGMENT DISPLAY"
add_wave -radix ascii    -name "7-Segment Display (ASCII)" /tb_fpga_bist_top/display_ascii
add_wave -radix hex      -name "Display Word [15:0]"      /tb_fpga_bist_top/display_word
add_wave -radix hex      -name "GPIO LEDs [7:0] (0xAD)"   /tb_fpga_bist_top/gpio_led
add_wave -radix unsigned -name "Verified Count (1199)"    /tb_fpga_bist_top/pass_count
add_wave -color green    -name "PASS Flag (1=PASS)"       /tb_fpga_bist_top/all_passed

puts "INFO: Clean demonstration waveform layout loaded."
