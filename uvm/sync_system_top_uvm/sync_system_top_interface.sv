interface sync_system_top_inter (input bit clk);
    // ---------------- DUT inputs ----------------
    logic                rst_n;
    logic signed [11:0]  in_sample_i;
    logic signed [11:0]  in_sample_q;
    logic                in_sample_valid;
    logic [1:0]          mod_type;
    logic [7:0]          loop_gain;
    logic [7:0]          costas_loop_gain;
    logic [3:0]          dft_sel;
    logic                start_of_burst;
    logic                force_w_en;
    logic [15:0]         force_w;
    logic                force_cfo_en;
    logic signed [23:0]  force_cfo;
    logic                force_freq_en;
    logic [31:0]         force_freq;

    // ---------------- DUT outputs ----------------
    logic signed [15:0]  out_sym_i;
    logic signed [15:0]  out_sym_q;
    logic                out_sym_valid;
    logic signed [23:0]  coarse_cfo_est;
    logic signed [31:0]  fine_cfo_est;
    logic                lock_detect;
    logic                flush_active;
    logic [7:0]          valid_during_flush;
    logic [31:0]         dft_obs_data;

    // ---------------- internal taps (assigned in the top module) ----------------
    logic [2:0]          fsm_state;     // dut.fsm_state (burst FSM)
    logic                str_lock;      // dut.str_lock
    logic                costas_lock;   // dut.costas_lock
    logic                coarse_valid;  // dut.coarse_valid
    logic                str_valid;     // dut.str_valid
endinterface
