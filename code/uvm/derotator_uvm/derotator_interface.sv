interface derotator_inter (input bit clk);
    logic        rst_ni;
    logic        s_axis_valid_i;
    logic signed [15:0] s_axis_i_sym_i;
    logic signed [15:0] s_axis_q_sym_i;
    logic        coarse_valid_i;
    logic signed [23:0] coarse_word_i;
    logic        freq_adj_valid_i;
    logic signed [31:0] freq_adj_i;
    logic        force_freq_en_i;
    logic        [31:0] force_freq_i;
    logic        phase_adj_valid_i;
    logic        [31:0] phase_adj_i;
    
    logic        m_axis_valid_o;
    logic signed [15:0] m_axis_i_sym_o;
    logic signed [15:0] m_axis_q_sym_o;
    logic        [31:0] phase_o;
    logic        [31:0] freq_word_o;

    initial begin
        rst_ni = 0;
        s_axis_valid_i = 0;
        s_axis_i_sym_i = 0;
        s_axis_q_sym_i = 0;
        coarse_valid_i = 0;
        coarse_word_i = 0;
        freq_adj_valid_i = 0;
        freq_adj_i = 0;
        force_freq_en_i = 0;
        force_freq_i = 0;
        phase_adj_valid_i = 0;
        phase_adj_i = 0;
    end
endinterface