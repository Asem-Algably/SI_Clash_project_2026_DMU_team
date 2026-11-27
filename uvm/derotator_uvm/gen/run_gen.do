if {[file exists work_gen]} {vdel -lib work_gen -all}
vlib work_gen
vlog -work work_gen gen/gen_derot_cases.sv
vsim -c -work work_gen -sv_seed 20261129 work_gen.gen_derot_cases -do "run -all; quit -f"
