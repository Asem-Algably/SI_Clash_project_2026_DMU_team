# ==============================================================================
# Script Name : add_debug_cores.tcl
# Project     : SI-CLASH Real-Time Digital Synchronizer - ZCU106 Standalone BIST
# Tool        : AMD Xilinx Vivado (v2018.2+)
# Description : Automatically creates, parameterizes, and generates the VIO and
#               ILA debug IP cores used by fpga_bist_top.sv.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Create & Configure VIO Core (Virtual Dashboard: 6 Probe In, 1 Probe Out)
# ------------------------------------------------------------------------------
# Probes Mapping:
#   probe_in0 [15:0] : pass_count_q        (Symbols verified count)
#   probe_in1 [7:0]  : status_code         (0xAA = PASS, 0xEE = ERROR)
#   probe_in2 [0:0]  : all_passed_q        (Overall pass flag)
#   probe_in3 [0:0]  : error_latch_q       (Error sticky flag)
#   probe_in4 [0:0]  : str_locked_sticky   (STR loop lock)
#   probe_in5 [0:0]  : costas_locked_sticky(Costas loop lock)
#   probe_out0[0:0]  : vio_restart_btn     (Virtual GUI restart button)
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_0
set_property -dict [list \
  CONFIG.C_NUM_PROBE_IN     {6}  \
  CONFIG.C_PROBE_IN0_WIDTH  {16} \
  CONFIG.C_PROBE_IN1_WIDTH  {8}  \
  CONFIG.C_PROBE_IN2_WIDTH  {1}  \
  CONFIG.C_PROBE_IN3_WIDTH  {1}  \
  CONFIG.C_PROBE_IN4_WIDTH  {1}  \
  CONFIG.C_PROBE_IN5_WIDTH  {1}  \
  CONFIG.C_NUM_PROBE_OUT    {1}  \
  CONFIG.C_PROBE_OUT0_WIDTH {1}  \
] [get_ips vio_0]
generate_target all [get_ips vio_0]

# ------------------------------------------------------------------------------
# 2. Create & Configure ILA Core (Logic Analyzer: 8 Probes, 2048 Sample Depth)
# ------------------------------------------------------------------------------
# Probes Mapping:
#   probe0 [0:0]  : dut_out_sym_valid (Symbol valid strobe)
#   probe1 [15:0] : dut_out_sym_i     (Recovered I symbol)
#   probe2 [15:0] : dut_out_sym_q     (Recovered Q symbol)
#   probe3 [15:0] : exp_sym_i         (Golden reference I)
#   probe4 [15:0] : exp_sym_q         (Golden reference Q)
#   probe5 [0:0]  : sym_match         (Bit-exact match flag)
#   probe6 [0:0]  : sym_mismatch      (Mismatch pulse flag)
#   probe7 [3:0]  : bist_state_q      (FSM state 0..A)
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list \
  CONFIG.C_DATA_DEPTH    {2048} \
  CONFIG.C_NUM_OF_PROBES {8}    \
  CONFIG.C_PROBE0_WIDTH  {1}    \
  CONFIG.C_PROBE1_WIDTH  {16}   \
  CONFIG.C_PROBE2_WIDTH  {16}   \
  CONFIG.C_PROBE3_WIDTH  {16}   \
  CONFIG.C_PROBE4_WIDTH  {16}   \
  CONFIG.C_PROBE5_WIDTH  {1}    \
  CONFIG.C_PROBE6_WIDTH  {1}    \
  CONFIG.C_PROBE7_WIDTH  {4}    \
] [get_ips ila_0]
generate_target all [get_ips ila_0]
