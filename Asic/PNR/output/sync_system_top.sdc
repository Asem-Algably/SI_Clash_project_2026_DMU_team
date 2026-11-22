###################################################################

# Created by write_sdc on Wed Nov 20 02:22:33 2019

###################################################################
set sdc_version 1.9

set_units -time ns -resistance MOhm -capacitance fF -voltage V -current mA
create_clock [get_ports clk]  -period 5  -waveform {0 2.5}
set_clock_uncertainty 0.35  [get_clocks clk]
set_false_path -hold   -from [list [get_ports rst_n] [get_ports {in_sample_i[11]}] [get_ports        \
{in_sample_i[10]}] [get_ports {in_sample_i[9]}] [get_ports {in_sample_i[8]}]   \
[get_ports {in_sample_i[7]}] [get_ports {in_sample_i[6]}] [get_ports           \
{in_sample_i[5]}] [get_ports {in_sample_i[4]}] [get_ports {in_sample_i[3]}]    \
[get_ports {in_sample_i[2]}] [get_ports {in_sample_i[1]}] [get_ports           \
{in_sample_i[0]}] [get_ports {in_sample_q[11]}] [get_ports {in_sample_q[10]}]  \
[get_ports {in_sample_q[9]}] [get_ports {in_sample_q[8]}] [get_ports           \
{in_sample_q[7]}] [get_ports {in_sample_q[6]}] [get_ports {in_sample_q[5]}]    \
[get_ports {in_sample_q[4]}] [get_ports {in_sample_q[3]}] [get_ports           \
{in_sample_q[2]}] [get_ports {in_sample_q[1]}] [get_ports {in_sample_q[0]}]    \
[get_ports in_sample_valid] [get_ports {mod_type[1]}] [get_ports               \
{mod_type[0]}] [get_ports {loop_gain[7]}] [get_ports {loop_gain[6]}]           \
[get_ports {loop_gain[5]}] [get_ports {loop_gain[4]}] [get_ports               \
{loop_gain[3]}] [get_ports {loop_gain[2]}] [get_ports {loop_gain[1]}]          \
[get_ports {loop_gain[0]}] [get_ports {costas_loop_gain[7]}] [get_ports        \
{costas_loop_gain[6]}] [get_ports {costas_loop_gain[5]}] [get_ports            \
{costas_loop_gain[4]}] [get_ports {costas_loop_gain[3]}] [get_ports            \
{costas_loop_gain[2]}] [get_ports {costas_loop_gain[1]}] [get_ports            \
{costas_loop_gain[0]}] [get_ports {dft_sel[3]}] [get_ports {dft_sel[2]}]       \
[get_ports {dft_sel[1]}] [get_ports {dft_sel[0]}] [get_ports start_of_burst]   \
[get_ports force_w_en] [get_ports {force_w[15]}] [get_ports {force_w[14]}]     \
[get_ports {force_w[13]}] [get_ports {force_w[12]}] [get_ports {force_w[11]}]  \
[get_ports {force_w[10]}] [get_ports {force_w[9]}] [get_ports {force_w[8]}]    \
[get_ports {force_w[7]}] [get_ports {force_w[6]}] [get_ports {force_w[5]}]     \
[get_ports {force_w[4]}] [get_ports {force_w[3]}] [get_ports {force_w[2]}]     \
[get_ports {force_w[1]}] [get_ports {force_w[0]}] [get_ports force_cfo_en]     \
[get_ports {force_cfo[23]}] [get_ports {force_cfo[22]}] [get_ports             \
{force_cfo[21]}] [get_ports {force_cfo[20]}] [get_ports {force_cfo[19]}]       \
[get_ports {force_cfo[18]}] [get_ports {force_cfo[17]}] [get_ports             \
{force_cfo[16]}] [get_ports {force_cfo[15]}] [get_ports {force_cfo[14]}]       \
[get_ports {force_cfo[13]}] [get_ports {force_cfo[12]}] [get_ports             \
{force_cfo[11]}] [get_ports {force_cfo[10]}] [get_ports {force_cfo[9]}]        \
[get_ports {force_cfo[8]}] [get_ports {force_cfo[7]}] [get_ports               \
{force_cfo[6]}] [get_ports {force_cfo[5]}] [get_ports {force_cfo[4]}]          \
[get_ports {force_cfo[3]}] [get_ports {force_cfo[2]}] [get_ports               \
{force_cfo[1]}] [get_ports {force_cfo[0]}] [get_ports force_freq_en]           \
[get_ports {force_freq[31]}] [get_ports {force_freq[30]}] [get_ports           \
{force_freq[29]}] [get_ports {force_freq[28]}] [get_ports {force_freq[27]}]    \
[get_ports {force_freq[26]}] [get_ports {force_freq[25]}] [get_ports           \
{force_freq[24]}] [get_ports {force_freq[23]}] [get_ports {force_freq[22]}]    \
[get_ports {force_freq[21]}] [get_ports {force_freq[20]}] [get_ports           \
{force_freq[19]}] [get_ports {force_freq[18]}] [get_ports {force_freq[17]}]    \
[get_ports {force_freq[16]}] [get_ports {force_freq[15]}] [get_ports           \
{force_freq[14]}] [get_ports {force_freq[13]}] [get_ports {force_freq[12]}]    \
[get_ports {force_freq[11]}] [get_ports {force_freq[10]}] [get_ports           \
{force_freq[9]}] [get_ports {force_freq[8]}] [get_ports {force_freq[7]}]       \
[get_ports {force_freq[6]}] [get_ports {force_freq[5]}] [get_ports             \
{force_freq[4]}] [get_ports {force_freq[3]}] [get_ports {force_freq[2]}]       \
[get_ports {force_freq[1]}] [get_ports {force_freq[0]}]]
set_false_path -hold   -to [list [get_ports {out_sym_i[15]}] [get_ports {out_sym_i[14]}] [get_ports  \
{out_sym_i[13]}] [get_ports {out_sym_i[12]}] [get_ports {out_sym_i[11]}]       \
[get_ports {out_sym_i[10]}] [get_ports {out_sym_i[9]}] [get_ports              \
{out_sym_i[8]}] [get_ports {out_sym_i[7]}] [get_ports {out_sym_i[6]}]          \
[get_ports {out_sym_i[5]}] [get_ports {out_sym_i[4]}] [get_ports               \
{out_sym_i[3]}] [get_ports {out_sym_i[2]}] [get_ports {out_sym_i[1]}]          \
[get_ports {out_sym_i[0]}] [get_ports {out_sym_q[15]}] [get_ports              \
{out_sym_q[14]}] [get_ports {out_sym_q[13]}] [get_ports {out_sym_q[12]}]       \
[get_ports {out_sym_q[11]}] [get_ports {out_sym_q[10]}] [get_ports             \
{out_sym_q[9]}] [get_ports {out_sym_q[8]}] [get_ports {out_sym_q[7]}]          \
[get_ports {out_sym_q[6]}] [get_ports {out_sym_q[5]}] [get_ports               \
{out_sym_q[4]}] [get_ports {out_sym_q[3]}] [get_ports {out_sym_q[2]}]          \
[get_ports {out_sym_q[1]}] [get_ports {out_sym_q[0]}] [get_ports               \
out_sym_valid] [get_ports {coarse_cfo_est[23]}] [get_ports                     \
{coarse_cfo_est[22]}] [get_ports {coarse_cfo_est[21]}] [get_ports              \
{coarse_cfo_est[20]}] [get_ports {coarse_cfo_est[19]}] [get_ports              \
{coarse_cfo_est[18]}] [get_ports {coarse_cfo_est[17]}] [get_ports              \
{coarse_cfo_est[16]}] [get_ports {coarse_cfo_est[15]}] [get_ports              \
{coarse_cfo_est[14]}] [get_ports {coarse_cfo_est[13]}] [get_ports              \
{coarse_cfo_est[12]}] [get_ports {coarse_cfo_est[11]}] [get_ports              \
{coarse_cfo_est[10]}] [get_ports {coarse_cfo_est[9]}] [get_ports               \
{coarse_cfo_est[8]}] [get_ports {coarse_cfo_est[7]}] [get_ports                \
{coarse_cfo_est[6]}] [get_ports {coarse_cfo_est[5]}] [get_ports                \
{coarse_cfo_est[4]}] [get_ports {coarse_cfo_est[3]}] [get_ports                \
{coarse_cfo_est[2]}] [get_ports {coarse_cfo_est[1]}] [get_ports                \
{coarse_cfo_est[0]}] [get_ports {fine_cfo_est[31]}] [get_ports                 \
{fine_cfo_est[30]}] [get_ports {fine_cfo_est[29]}] [get_ports                  \
{fine_cfo_est[28]}] [get_ports {fine_cfo_est[27]}] [get_ports                  \
{fine_cfo_est[26]}] [get_ports {fine_cfo_est[25]}] [get_ports                  \
{fine_cfo_est[24]}] [get_ports {fine_cfo_est[23]}] [get_ports                  \
{fine_cfo_est[22]}] [get_ports {fine_cfo_est[21]}] [get_ports                  \
{fine_cfo_est[20]}] [get_ports {fine_cfo_est[19]}] [get_ports                  \
{fine_cfo_est[18]}] [get_ports {fine_cfo_est[17]}] [get_ports                  \
{fine_cfo_est[16]}] [get_ports {fine_cfo_est[15]}] [get_ports                  \
{fine_cfo_est[14]}] [get_ports {fine_cfo_est[13]}] [get_ports                  \
{fine_cfo_est[12]}] [get_ports {fine_cfo_est[11]}] [get_ports                  \
{fine_cfo_est[10]}] [get_ports {fine_cfo_est[9]}] [get_ports                   \
{fine_cfo_est[8]}] [get_ports {fine_cfo_est[7]}] [get_ports {fine_cfo_est[6]}] \
[get_ports {fine_cfo_est[5]}] [get_ports {fine_cfo_est[4]}] [get_ports         \
{fine_cfo_est[3]}] [get_ports {fine_cfo_est[2]}] [get_ports {fine_cfo_est[1]}] \
[get_ports {fine_cfo_est[0]}] [get_ports lock_detect] [get_ports               \
{dft_obs_data[31]}] [get_ports {dft_obs_data[30]}] [get_ports                  \
{dft_obs_data[29]}] [get_ports {dft_obs_data[28]}] [get_ports                  \
{dft_obs_data[27]}] [get_ports {dft_obs_data[26]}] [get_ports                  \
{dft_obs_data[25]}] [get_ports {dft_obs_data[24]}] [get_ports                  \
{dft_obs_data[23]}] [get_ports {dft_obs_data[22]}] [get_ports                  \
{dft_obs_data[21]}] [get_ports {dft_obs_data[20]}] [get_ports                  \
{dft_obs_data[19]}] [get_ports {dft_obs_data[18]}] [get_ports                  \
{dft_obs_data[17]}] [get_ports {dft_obs_data[16]}] [get_ports                  \
{dft_obs_data[15]}] [get_ports {dft_obs_data[14]}] [get_ports                  \
{dft_obs_data[13]}] [get_ports {dft_obs_data[12]}] [get_ports                  \
{dft_obs_data[11]}] [get_ports {dft_obs_data[10]}] [get_ports                  \
{dft_obs_data[9]}] [get_ports {dft_obs_data[8]}] [get_ports {dft_obs_data[7]}] \
[get_ports {dft_obs_data[6]}] [get_ports {dft_obs_data[5]}] [get_ports         \
{dft_obs_data[4]}] [get_ports {dft_obs_data[3]}] [get_ports {dft_obs_data[2]}] \
[get_ports {dft_obs_data[1]}] [get_ports {dft_obs_data[0]}]]
set_input_delay -clock clk  -max 1  [get_ports rst_n]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[11]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[10]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[9]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[8]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[7]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[6]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[5]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[4]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[3]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[2]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[1]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_i[0]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[11]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[10]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[9]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[8]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[7]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[6]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[5]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[4]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[3]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[2]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[1]}]
set_input_delay -clock clk  -max 1  [get_ports {in_sample_q[0]}]
set_input_delay -clock clk  -max 1  [get_ports in_sample_valid]
set_input_delay -clock clk  -max 1  [get_ports {mod_type[1]}]
set_input_delay -clock clk  -max 1  [get_ports {mod_type[0]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[7]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[6]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[5]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[4]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[3]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[2]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[1]}]
set_input_delay -clock clk  -max 1  [get_ports {loop_gain[0]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[7]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[6]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[5]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[4]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[3]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[2]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[1]}]
set_input_delay -clock clk  -max 1  [get_ports {costas_loop_gain[0]}]
set_input_delay -clock clk  -max 1  [get_ports {dft_sel[3]}]
set_input_delay -clock clk  -max 1  [get_ports {dft_sel[2]}]
set_input_delay -clock clk  -max 1  [get_ports {dft_sel[1]}]
set_input_delay -clock clk  -max 1  [get_ports {dft_sel[0]}]
set_input_delay -clock clk  -max 1  [get_ports start_of_burst]
set_input_delay -clock clk  -max 1  [get_ports force_w_en]
set_input_delay -clock clk  -max 1  [get_ports {force_w[15]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[14]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[13]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[12]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[11]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[10]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[9]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[8]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[7]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[6]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[5]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[4]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[3]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[2]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[1]}]
set_input_delay -clock clk  -max 1  [get_ports {force_w[0]}]
set_input_delay -clock clk  -max 1  [get_ports force_cfo_en]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[23]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[22]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[21]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[20]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[19]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[18]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[17]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[16]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[15]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[14]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[13]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[12]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[11]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[10]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[9]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[8]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[7]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[6]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[5]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[4]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[3]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[2]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[1]}]
set_input_delay -clock clk  -max 1  [get_ports {force_cfo[0]}]
set_input_delay -clock clk  -max 1  [get_ports force_freq_en]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[31]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[30]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[29]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[28]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[27]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[26]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[25]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[24]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[23]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[22]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[21]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[20]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[19]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[18]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[17]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[16]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[15]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[14]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[13]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[12]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[11]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[10]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[9]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[8]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[7]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[6]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[5]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[4]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[3]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[2]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[1]}]
set_input_delay -clock clk  -max 1  [get_ports {force_freq[0]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[15]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[14]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[13]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[12]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[11]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[10]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[9]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[8]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[7]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[6]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[5]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[4]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[3]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[2]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[1]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_i[0]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[15]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[14]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[13]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[12]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[11]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[10]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[9]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[8]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[7]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[6]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[5]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[4]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[3]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[2]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[1]}]
set_output_delay -clock clk  -max 1  [get_ports {out_sym_q[0]}]
set_output_delay -clock clk  -max 1  [get_ports out_sym_valid]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[23]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[22]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[21]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[20]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[19]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[18]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[17]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[16]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[15]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[14]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[13]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[12]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[11]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[10]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[9]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[8]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[7]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[6]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[5]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[4]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[3]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[2]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[1]}]
set_output_delay -clock clk  -max 1  [get_ports {coarse_cfo_est[0]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[31]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[30]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[29]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[28]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[27]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[26]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[25]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[24]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[23]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[22]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[21]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[20]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[19]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[18]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[17]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[16]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[15]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[14]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[13]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[12]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[11]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[10]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[9]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[8]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[7]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[6]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[5]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[4]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[3]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[2]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[1]}]
set_output_delay -clock clk  -max 1  [get_ports {fine_cfo_est[0]}]
set_output_delay -clock clk  -max 1  [get_ports lock_detect]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[31]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[30]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[29]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[28]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[27]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[26]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[25]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[24]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[23]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[22]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[21]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[20]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[19]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[18]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[17]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[16]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[15]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[14]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[13]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[12]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[11]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[10]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[9]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[8]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[7]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[6]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[5]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[4]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[3]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[2]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[1]}]
set_output_delay -clock clk  -max 1  [get_ports {dft_obs_data[0]}]
