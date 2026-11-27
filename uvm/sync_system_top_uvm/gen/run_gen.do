if {[file exists work_gen]} {vdel -lib work_gen -all}
vlib work_gen
vlog -work work_gen gen/gen_top_cases.sv
vsim -c -work work_gen -sv_seed 20261126 work_gen.gen_top_cases -do "run -all; quit -f"
