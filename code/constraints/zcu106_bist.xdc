# ==============================================================================
# File Name    : zcu106_bist.xdc
# Project      : SI-CLASH Real-Time Digital Synchronizer - ZCU106 Standalone BIST
# Target Board : AMD Xilinx ZCU106 Evaluation Kit (XCZU7EV-2FFVC1156-2-E)
# Top Module   : fpga_bist_top
# Description  : Physical constraints (Pinout, IOSTANDARD, Slew, Drive) and
#                Timing constraints (Clocks, False Paths) for the Hardware BIST.
# Reference    : AMD Xilinx ZCU106 Board User Guide (UG1244)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Primary Clock Input (125.00 MHz Differential on PL Bank 28)
# ------------------------------------------------------------------------------
set_property PACKAGE_PIN H9 [get_ports clk_125_p]
set_property PACKAGE_PIN G9 [get_ports clk_125_n]
set_property IOSTANDARD LVDS [get_ports clk_125_p]
set_property IOSTANDARD LVDS [get_ports clk_125_n]

# 125.00 MHz primary oscillator period = 8.000 ns
create_clock -period 8.000 -name clk_125_p [get_ports clk_125_p]

# ------------------------------------------------------------------------------
# 2. Pushbutton Reset / Restart (User SW14 Center Button)
# ------------------------------------------------------------------------------
# SW14 Center Pushbutton: Active-High (1'b1 when pressed)
set_property PACKAGE_PIN AL10 [get_ports btn_sw14]
set_property IOSTANDARD LVCMOS12 [get_ports btn_sw14]
set_false_path -from [get_ports btn_sw14]

# ------------------------------------------------------------------------------
# 3. On-Board GPIO LEDs (Bank 66 - 1.2V)
# ------------------------------------------------------------------------------
# [0] = BIST_PASSED (LED0)
# [1] = BIST_FAILED (LED1)
# [2] = STR_LOCKED  (LED2)
# [3] = COSTAS_LOCKED (LED3)
# [7:4] = FSM State (LED7..4)
set_property PACKAGE_PIN AL11 [get_ports {gpio_led[0]}]
set_property PACKAGE_PIN AL13 [get_ports {gpio_led[1]}]
set_property PACKAGE_PIN AK13 [get_ports {gpio_led[2]}]
set_property PACKAGE_PIN AE15 [get_ports {gpio_led[3]}]
set_property PACKAGE_PIN AM8  [get_ports {gpio_led[4]}]
set_property PACKAGE_PIN AM9  [get_ports {gpio_led[5]}]
set_property PACKAGE_PIN AM10 [get_ports {gpio_led[6]}]
set_property PACKAGE_PIN AM11 [get_ports {gpio_led[7]}]

set_property IOSTANDARD LVCMOS12 [get_ports {gpio_led[*]}]
set_property DRIVE 8             [get_ports {gpio_led[*]}]
set_property SLEW SLOW           [get_ports {gpio_led[*]}]
set_false_path -to [get_ports {gpio_led[*]}]

# ------------------------------------------------------------------------------
# 4. PMOD 7-Segment Display (J55 Segments & DP, J87 Digit Anodes)
# ------------------------------------------------------------------------------
# PMOD0 (J55 Header, Level-shifted to 1.8V Bank 66/68) - 7 Segments + DP
# Segment A (CA) -> J55 Pin 1 (PMOD0_0)
set_property PACKAGE_PIN B23 [get_ports {pmod_seg_o[0]}]
# Segment B (CB) -> J55 Pin 3 (PMOD0_1)
set_property PACKAGE_PIN A23 [get_ports {pmod_seg_o[1]}]
# Segment C (CC) -> J55 Pin 5 (PMOD0_2)
set_property PACKAGE_PIN F25 [get_ports {pmod_seg_o[2]}]
# Segment D (CD) -> J55 Pin 7 (PMOD0_3)
set_property PACKAGE_PIN E20 [get_ports {pmod_seg_o[3]}]
# Segment E (CE) -> J55 Pin 2 (PMOD0_4)
set_property PACKAGE_PIN K24 [get_ports {pmod_seg_o[4]}]
# Segment F (CF) -> J55 Pin 4 (PMOD0_5)
set_property PACKAGE_PIN L23 [get_ports {pmod_seg_o[5]}]
# Segment G (CG) -> J55 Pin 6 (PMOD0_6)
set_property PACKAGE_PIN L22 [get_ports {pmod_seg_o[6]}]
# Decimal Point (DP) -> J55 Pin 8 (PMOD0_7)
set_property PACKAGE_PIN D7  [get_ports pmod_dp_o]

set_property IOSTANDARD LVCMOS18 [get_ports {pmod_seg_o[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports pmod_dp_o]
set_property DRIVE 8             [get_ports {pmod_seg_o[*]}]
set_property DRIVE 8             [get_ports pmod_dp_o]
set_property SLEW SLOW           [get_ports {pmod_seg_o[*]}]
set_property SLEW SLOW           [get_ports pmod_dp_o]

# PMOD1 (J87 Header, Connected to 1.2V Bank 66) - 4 Digit Anodes
# Anode 0 (AN0 - Rightmost Digit) -> J87 Pin 1 (PMOD1_0)
set_property PACKAGE_PIN AN8  [get_ports {pmod_an_o[0]}]
# Anode 1 (AN1)                   -> J87 Pin 3 (PMOD1_1)
set_property PACKAGE_PIN AN9  [get_ports {pmod_an_o[1]}]
# Anode 2 (AN2)                   -> J87 Pin 5 (PMOD1_2)
set_property PACKAGE_PIN AP11 [get_ports {pmod_an_o[2]}]
# Anode 3 (AN3 - Leftmost Digit)  -> J87 Pin 7 (PMOD1_3)
set_property PACKAGE_PIN AN11 [get_ports {pmod_an_o[3]}]

set_property IOSTANDARD LVCMOS12 [get_ports {pmod_an_o[*]}]
set_property DRIVE 8             [get_ports {pmod_an_o[*]}]
set_property SLEW SLOW           [get_ports {pmod_an_o[*]}]

set_false_path -to [get_ports {pmod_seg_o[*] pmod_dp_o pmod_an_o[*]}]

# ------------------------------------------------------------------------------
# 5. Configuration & Bitstream Generation Directives
# ------------------------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
