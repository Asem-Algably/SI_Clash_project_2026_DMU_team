# ============================================================
# run_str_top.do
# Standalone STR test — compiles deps if needed, launches GUI,
# adds key waves, runs to completion.
#
# Assumes: work library exists with tb_str_top already compiled.
# If not, uncomment the compile block below.
# ============================================================

# ---- Uncomment if you need to recompile everything first ----
# if {[file exists work]} { vdel -all -lib work }
# vlib work
# vmap work work
# vlog -sv +incdir+. reset_sync.sv
# vlog -sv +incdir+. parabolic_farrow_interpolator.sv
# vlog -sv +incdir+. gardner_ted_estimator.sv
# vlog -sv +incdir+. pI_loop.sv
# vlog -sv +incdir+. modulo_1_controller.sv
# vlog -sv +incdir+. str_top.sv
# vlog -sv +incdir+. tb_str_top.sv
# -------------------------------------------------------------

echo "=========================================="
echo "Running tb_str_top (standalone STR)"
echo "=========================================="

vsim -gui -voptargs=+acc work.tb_str_top

view wave
configure wave -signalnamewidth 1
configure wave -namecolwidth 260
configure wave -valuecolwidth 100
configure wave -timelineunits ns

# ---- 1. Clock / Reset ----
add wave -divider "Clock / Reset"
add wave -position insertpoint sim:/tb_str_top/clk
add wave -position insertpoint sim:/tb_str_top/rst_n

# ---- 2. Input side ----
add wave -divider "Input (from TB)"
add wave -position insertpoint sim:/tb_str_top/in_valid
add wave -position insertpoint -radix decimal sim:/tb_str_top/in_i
add wave -position insertpoint -radix decimal sim:/tb_str_top/in_q
add wave -position insertpoint -radix unsigned sim:/tb_str_top/in_valid_cnt

# ---- 3. Output side (STR result) ----
add wave -divider "Output (STR)"
add wave -position insertpoint sim:/tb_str_top/out_valid
add wave -position insertpoint -radix decimal sim:/tb_str_top/out_i
add wave -position insertpoint -radix decimal sim:/tb_str_top/out_q
add wave -position insertpoint -radix unsigned sim:/tb_str_top/out_valid_cnt

# ---- 4. Loop state ----
add wave -divider "Loop State"
add wave -position insertpoint sim:/tb_str_top/lock_o
add wave -position insertpoint -radix decimal sim:/tb_str_top/w_o
add wave -position insertpoint -radix decimal sim:/tb_str_top/mu_o
add wave -position insertpoint -radix decimal sim:/tb_str_top/ted_err_o
add wave -position insertpoint sim:/tb_str_top/ted_err_valid

# ---- 5. Internal: modulo-1 controller (strobe generation) ----
add wave -divider "Modulo-1 Controller"
add wave -position insertpoint -radix unsigned sim:/tb_str_top/u_str/u_modulo_ctrl/m_q
add wave -position insertpoint -radix unsigned sim:/tb_str_top/u_str/u_modulo_ctrl/m_next
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/u_modulo_ctrl/w
add wave -position insertpoint sim:/tb_str_top/u_str/u_modulo_ctrl/curr_cross
add wave -position insertpoint sim:/tb_str_top/u_str/u_modulo_ctrl/mid_cross
add wave -position insertpoint sim:/tb_str_top/u_str/curr_strobe
add wave -position insertpoint sim:/tb_str_top/u_str/mid_strobe
add wave -position insertpoint sim:/tb_str_top/u_str/curr_strobe_d
add wave -position insertpoint sim:/tb_str_top/u_str/mid_strobe_d

# ---- 6. Internal: interpolator output ----
add wave -divider "Interpolator Output"
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/i_y
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/q_y

# ---- 7. Internal: TED and PI ----
add wave -divider "TED and PI"
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/u_ted/error_sum
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/ted_error
add wave -position insertpoint sim:/tb_str_top/u_str/ted_error_valid
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/pi_val

# ---- 8. Internal: lock detector ----
add wave -divider "Lock Detector"
add wave -position insertpoint -radix unsigned sim:/tb_str_top/u_str/abs_error
add wave -position insertpoint -radix unsigned sim:/tb_str_top/u_str/ema_q
add wave -position insertpoint -radix unsigned sim:/tb_str_top/u_str/leaky_bucket

# ---- 9. Strobes and sampled symbols ----
add wave -divider "Sampled Symbols"
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/i_mid
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/i_cur
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/i_prev
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/q_mid
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/q_cur
add wave -position insertpoint -radix decimal sim:/tb_str_top/u_str/q_prev

run -all
wave zoom full