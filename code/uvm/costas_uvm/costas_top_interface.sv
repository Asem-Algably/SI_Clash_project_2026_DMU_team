interface costas_top_inter (input bit clk);
    logic                rst_n;
    logic                s_axis_valid_i;
    logic signed [15:0]  s_axis_i_sym_i;
    logic signed [15:0]  s_axis_q_sym_i;
    logic [1:0]          mod_type_i;
    logic [7:0]          costas_gain_i;
    logic [1:0]          mode_i;
    logic                slicer_qpsk_i;
    logic                preamble_end_i;

    logic                freq_adj_valid_o;
    logic signed [31:0]  freq_adj_o;
    logic signed [31:0]  int_o;
    logic                phase_adj_valid_o;
    logic        [31:0]  phase_adj_o;
    logic                quad_unresolved_o;
    logic                lock_o;

    logic signed [15:0]  dbg_e_o;
    logic                dbg_e_valid_o;
    logic                dbg_lock_int_o;
    logic                dbg_quad_done_o;
endinterface