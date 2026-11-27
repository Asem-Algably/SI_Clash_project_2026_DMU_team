package derotator_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    class derotator_seq_item extends uvm_sequence_item;
        `uvm_object_utils(derotator_seq_item)
        
        // Inputs
        rand logic               rst_ni            = 1'b1;
        rand logic               s_axis_valid_i    = 1'b0;
        rand logic signed [15:0] s_axis_i_sym_i    = '0;
        rand logic signed [15:0] s_axis_q_sym_i    = '0;
        rand logic               coarse_valid_i    = 1'b0;
        rand logic signed [23:0] coarse_word_i     = '0;
        rand logic               freq_adj_valid_i  = 1'b0;
        rand logic signed [31:0] freq_adj_i        = '0;
        rand logic               force_freq_en_i   = 1'b0;
        rand logic        [31:0] force_freq_i      = '0;
        rand logic               phase_adj_valid_i = 1'b0;
        rand logic        [31:0] phase_adj_i       = '0;

        // Outputs
        logic        m_axis_valid_o;
        logic signed [15:0] m_axis_i_sym_o;
        logic signed [15:0] m_axis_q_sym_o;
        logic        [31:0] phase_o;
        logic        [31:0] freq_word_o;

        // Expected (For Scoreboard)
        logic               exp_valid = 1'b0;
        logic signed [15:0] exp_i     = '0;
        logic signed [15:0] exp_q     = '0;

        function new(string name = "derotator_seq_item");
            super.new(name);
        endfunction
    endclass
endpackage