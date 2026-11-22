module sva (
    input logic         clk_i,
    input logic         rst_ni,

    // Inputs
    input logic         s_axis_valid_i,
    input logic         force_freq_en_i,
    input logic [31:0]  force_freq_i,
    
    // Outputs
    input logic         m_axis_valid_o,
    input logic signed [15:0] m_axis_i_sym_o,
    input logic signed [15:0] m_axis_q_sym_o,
    input logic [31:0]  freq_word_o
);

    // 1. Check that outputs are NOT X when valid is high
    property p_known_out;
        @(posedge clk_i) disable iff (!rst_ni)
        m_axis_valid_o |-> !$isunknown({m_axis_i_sym_o, m_axis_q_sym_o});
    endproperty
    a_known_out: assert property(p_known_out)
        else $error("SVA Error: Output symbols contain X when m_axis_valid_o is high");

    // 2. Check that m_axis_valid_o only goes high if there was a valid input recently
    // (Using a non-strict check to avoid false failures due to exact cycle counting)
    property p_valid_origin;
        @(posedge clk_i) disable iff (!rst_ni)
        m_axis_valid_o |-> $past(s_axis_valid_i, 3);
    endproperty
    a_valid_origin: assert property(p_valid_origin)
        else $error("SVA Error: m_axis_valid_o went high without a valid input 3 cycles ago");

endmodule