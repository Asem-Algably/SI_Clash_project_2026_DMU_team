# ==========================================
# ModelSim Automation Script for STR (Symbol Timing Recovery)
# ==========================================

# 1. Compile RTL Files
echo "=========================================="
echo "Compiling RTL Files..."
echo "=========================================="
vlog -sv parabolic_farrow_interpolator.sv
vlog -sv modulo_1_controller.sv
vlog -sv pI_loop.sv
vlog -sv gardner_ted_estimator.sv
vlog -sv top.sv

# 2. Compile Testbench Files
echo "=========================================="
echo "Compiling Testbench Files..."
echo "=========================================="
vlog -sv tb_parabolic_farrow_interpolator.sv
vlog -sv tb_modulo_1_controller.sv
vlog -sv tb_pI_loop.sv
vlog -sv tb_gardner_ted_estimator.sv
vlog -sv tb_top.sv


# ==========================================
# 3. Run Testbenches
# ==========================================

# ---------------------------------------------------------
# Run 1: Parabolic Farrow Interpolator
# ---------------------------------------------------------
echo "=========================================="
echo "Running TB: Parabolic Farrow Interpolator"
echo "=========================================="
vsim -gui -voptargs="+acc" work.tb_parabolic_farrow_interpolator
view wave
delete wave *
add wave -divider "Control Signals"
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/clk_i
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/rst_n_i
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/valid_sample_i
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/valid_sample_o
add wave -divider "Data Path"
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/x_i
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/mu_i
add wave -position insertpoint sim:/tb_parabolic_farrow_interpolator/y_o
run -all
wave zoom full
quit -sim


# ---------------------------------------------------------
# Run 2: Modulo-1 Controller (NCO)
# ---------------------------------------------------------
echo "=========================================="
echo "Running TB: Modulo-1 Controller"
echo "=========================================="
vsim -gui -voptargs="+acc" work.tb_modulo_1_controller
view wave
delete wave *
add wave -divider "Control Signals"
add wave -position insertpoint sim:/tb_modulo_1_controller/clk_i
add wave -position insertpoint sim:/tb_modulo_1_controller/rst_n_i
add wave -position insertpoint sim:/tb_modulo_1_controller/valid_sample_i
add wave -position insertpoint sim:/tb_modulo_1_controller/pi_i
add wave -divider "Outputs"
add wave -position insertpoint sim:/tb_modulo_1_controller/w_o
add wave -position insertpoint sim:/tb_modulo_1_controller/mu_o
add wave -position insertpoint sim:/tb_modulo_1_controller/mid_strobe_o
add wave -position insertpoint sim:/tb_modulo_1_controller/current_strobe_o
run -all
wave zoom full
quit -sim


# ---------------------------------------------------------
# Run 3: PI Loop Filter
# ---------------------------------------------------------
echo "=========================================="
echo "Running TB: PI Loop Filter"
echo "=========================================="
vsim -gui -voptargs="+acc" work.tb_pI_loop
view wave
delete wave *
add wave -divider "Control Signals"
add wave -position insertpoint sim:/tb_pI_loop/clk_i
add wave -position insertpoint sim:/tb_pI_loop/rst_n_i
add wave -position insertpoint sim:/tb_pI_loop/valid_i
add wave -position insertpoint sim:/tb_pI_loop/error_i
add wave -divider "Outputs"
add wave -position insertpoint sim:/tb_pI_loop/pi_o
run -all
wave zoom full
quit -sim


# ---------------------------------------------------------
# Run 4: Gardner TED Estimator
# ---------------------------------------------------------
echo "=========================================="
echo "Running TB: Gardner TED Estimator"
echo "=========================================="
vsim -gui -voptargs="+acc" work.tb_gardner_ted_estimator
view wave
delete wave *
add wave -divider "Control Signals"
add wave -position insertpoint sim:/tb_gardner_ted_estimator/clk_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/rst_n_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/valid_i
add wave -divider "Inputs"
add wave -position insertpoint sim:/tb_gardner_ted_estimator/i_mid_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/i_cur_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/i_prev_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/q_mid_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/q_cur_i
add wave -position insertpoint sim:/tb_gardner_ted_estimator/q_prev_i
add wave -divider "Outputs"
add wave -position insertpoint sim:/tb_gardner_ted_estimator/error_o
run -all
wave zoom full
quit -sim


# ---------------------------------------------------------
# Run 5: Full System Top Level
# ---------------------------------------------------------
echo "=========================================="
echo "Running TB: Top Level Integration"
echo "=========================================="
vsim -gui -voptargs="+acc" work.tb_top
view wave
delete wave *

# Group 1: System Inputs
add wave -divider "System Inputs"
add wave -position insertpoint sim:/tb_top/clk_i
add wave -position insertpoint sim:/tb_top/rst_ni
add wave -position insertpoint sim:/tb_top/s_axis_valid_i
add wave -position insertpoint sim:/tb_top/s_axis_i_sample_i
add wave -position insertpoint sim:/tb_top/s_axis_q_sample_i

# Group 2: Internal Loop Signals (via DUT)
add wave -divider "Internal Loop Signals"
add wave -position insertpoint sim:/tb_top/dut/mu
add wave -position insertpoint sim:/tb_top/dut/pi_val
add wave -position insertpoint sim:/tb_top/dut/w_val
add wave -position insertpoint sim:/tb_top/dut/mid_strobe
add wave -position insertpoint sim:/tb_top/dut/curr_strobe
add wave -position insertpoint sim:/tb_top/dut/ted_error
add wave -position insertpoint sim:/tb_top/dut/i_y
add wave -position insertpoint sim:/tb_top/dut/q_y

# Group 3: Outputs
add wave -divider "System Outputs"
add wave -position insertpoint sim:/tb_top/m_axis_valid_o
add wave -position insertpoint sim:/tb_top/m_axis_i_sym_o
add wave -position insertpoint sim:/tb_top/m_axis_q_sym_o
add wave -position insertpoint sim:/tb_top/lock_o

run -all
wave zoom full

echo "=========================================="
echo "All Simulations Complete!"
echo "=========================================="