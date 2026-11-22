# ==========================================
# ModelSim Automation Script
# ==========================================

# 1. Compile RTL
vlog reset_sync.sv
vlog complex_mult.sv
vlog accumulator.sv
vlog cordic_angle.sv
vlog coarse_cfo_core.sv
vlog coarse_cfo_axi_wrapper.sv

# 2. Compile Testbenches
vlog -sv tb_checkpoint3_full.sv
vlog -sv tb_checkpoint5_dft.sv


# 3. Run Checkpoint 5 
echo "=========================================="
echo "Running Checkpoint 3 (Coarse CFO Sweep)"
echo "=========================================="
vsim -gui -voptargs=+acc work.tb_checkpoint5_dft
view wave
add wave -position insertpoint sim:/tb_checkpoint5_dft/u_dut/*  
run -all
wave zoom full


echo "=========================================="
echo "Simulation Complete!"
echo "=========================================="
