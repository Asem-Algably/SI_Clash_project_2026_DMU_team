interface str_top_inter (input bit clk);
    logic        rst_n;
    logic        s_axis_valid_i;
    logic        flush_active_i;
    logic [11:0] s_axis_i_sample_i;
    logic [11:0] s_axis_q_sample_i;
    logic [7:0]  loop_gain_i;
    logic        force_w_en_i;
    logic [15:0] force_w_i;

    logic        m_axis_valid_o;
    logic [15:0] m_axis_i_sym_o;
    logic [15:0] m_axis_q_sym_o;
    logic        lock_o;
    logic        ted_err_valid_o;
    logic [31:0] ted_err_o;
    logic [9:0]  mu_o;
    logic [15:0] w_o;
endinterface
