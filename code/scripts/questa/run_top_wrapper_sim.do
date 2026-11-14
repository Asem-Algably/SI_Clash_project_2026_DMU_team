# ============================================================================
# QuestaSim / ModelSim Top Wrapper Automation Script
# Project: SI-CLASH Real-Time Digital Synchronizer
# Usage:   In QuestaSim prompt: do code/scripts/questa/run_top_wrapper_sim.do
# ============================================================================

# Create work library if not present
vlib work
vmap work work

echo "=========================================="
echo "Compiling SI-CLASH Synchronizer RTL..."
echo "=========================================="

# 1. Compile Submodule RTL
vlog +acc -sv code/rtl/str/gardner_ted_estimator.sv
vlog +acc -sv code/rtl/str/modulo_1_controller.sv
vlog +acc -sv code/rtl/str/parabolic_farrow_interpolator.sv
vlog +acc -sv code/rtl/str/pI_loop.sv
vlog +acc -sv code/rtl/str/top.sv

vlog +acc -sv code/rtl/coarse_cfo/reset_sync.sv
vlog +acc -sv code/rtl/coarse_cfo/complex_mult.sv
vlog +acc -sv code/rtl/coarse_cfo/accumulator.sv
vlog +acc -sv code/rtl/coarse_cfo/cordic_angle.sv
vlog +acc -sv code/rtl/coarse_cfo/coarse_cfo_core.sv
vlog +acc -sv code/rtl/coarse_cfo/coarse_cfo_axi_wrapper.sv

vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/lut_rom.sv
vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/quadrant_rotator.sv
vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/input_pipeline.sv
vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/complex_multiplier.sv
vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/Freq_word.sv
vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/NCO_accumulator.sv
vlog +acc -sv +incdir+code/rtl/derotator code/rtl/derotator/derotator.sv

vlog +acc -sv code/rtl/costas/slicer.sv
vlog +acc -sv code/rtl/costas/phase_error.sv
vlog +acc -sv code/rtl/costas/pi_filter.sv
vlog +acc -sv code/rtl/costas/lock_detector.sv
vlog +acc -sv code/rtl/costas/quad_check.sv
vlog +acc -sv code/rtl/costas/costas_top.sv

# 2. Compile Top-Level Wrapper and FSM
vlog +acc -sv code/rtl/top/wrapper_fsm.sv
vlog +acc -sv code/rtl/top/top_wrapper.sv

# 3. Compile Top Testbench
vlog +acc -sv code/tb/top/tb_top_wrapper.sv

echo "=========================================="
echo "Starting Top Wrapper Simulation..."
echo "=========================================="

vsim -voptargs=+acc work.tb_top_wrapper

# Setup Waveform Window
view wave
add wave -divider "Top Interface"
add wave -format Logic /tb_top_wrapper/clk_i
add wave -format Logic /tb_top_wrapper/rst_ni
add wave -format Logic /tb_top_wrapper/s_axis_valid_i
add wave -format Literal -radix decimal /tb_top_wrapper/s_axis_i_sample_i
add wave -format Literal -radix decimal /tb_top_wrapper/s_axis_q_sample_i

add wave -divider "Wrapper FSM & Watchdog"
add wave -format Literal -radix unsigned /tb_top_wrapper/fsm_state_o
add wave -format Logic /tb_top_wrapper/flush_active_o
add wave -format Literal -radix unsigned /tb_top_wrapper/valid_during_flush_o

add wave -divider "Synchronizer Outputs"
add wave -format Logic /tb_top_wrapper/m_axis_valid_o
add wave -format Literal -radix decimal /tb_top_wrapper/m_axis_i_sym_o
add wave -format Literal -radix decimal /tb_top_wrapper/m_axis_q_sym_o
add wave -format Logic /tb_top_wrapper/lock_detect_o
add wave -format Literal -radix hex /tb_top_wrapper/coarse_cfo_est_o
add wave -format Literal -radix hex /tb_top_wrapper/fine_cfo_est_o

# Run Simulation
run -all
wave zoom full

echo "=========================================="
echo "Top Wrapper Simulation Complete!"
echo "=========================================="
