clear settings -lib
clear directives
configure output directory D:/qformal/Projects/Siclash_dmu/derotator

#### Directive Information ####
lint methodology soc -goal start 

#### vlib Information ####
vlib work

#### vmap Information ####
vmap work work

#### Compile Information ####
vlog D:/qformal/Projects/Siclash_dmu/derotator/lut_rom.sv -work work
vlog D:/qformal/Projects/Siclash_dmu/derotator/derotator.sv -work work
vlog D:/qformal/Projects/Siclash_dmu/derotator/Freq_word.sv -work work
vlog D:/qformal/Projects/Siclash_dmu/derotator/input_pipeline.sv -work work
vlog D:/qformal/Projects/Siclash_dmu/derotator/NCO_accumulator.sv -work work
vlog D:/qformal/Projects/Siclash_dmu/derotator/quadrant_rotator.sv -work work

#### Goal Information ####
lint run  -d derotator   -L work 
