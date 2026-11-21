import derotator_test_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"

module top ();
    bit clk ;
    initial begin
        forever begin
            #10 clk = !clk;
        end
    end
    
    derotator_inter derotator_test_vif(clk);
    
    // DUT Instantiation
    derotator dut (
        .clk_i              (derotator_test_vif.clk),
        .rst_ni             (derotator_test_vif.rst_ni),
        .s_axis_valid_i     (derotator_test_vif.s_axis_valid_i),
        .s_axis_i_sym_i     (derotator_test_vif.s_axis_i_sym_i),
        .s_axis_q_sym_i     (derotator_test_vif.s_axis_q_sym_i),
        .coarse_valid_i     (derotator_test_vif.coarse_valid_i),
        .coarse_word_i      (derotator_test_vif.coarse_word_i),
        .freq_adj_valid_i   (derotator_test_vif.freq_adj_valid_i),
        .freq_adj_i         (derotator_test_vif.freq_adj_i),
        .force_freq_en_i    (derotator_test_vif.force_freq_en_i),
        .force_freq_i       (derotator_test_vif.force_freq_i),
        .phase_adj_valid_i  (derotator_test_vif.phase_adj_valid_i),
        .phase_adj_i        (derotator_test_vif.phase_adj_i),
        .m_axis_valid_o     (derotator_test_vif.m_axis_valid_o),
        .m_axis_i_sym_o     (derotator_test_vif.m_axis_i_sym_o),
        .m_axis_q_sym_o     (derotator_test_vif.m_axis_q_sym_o),
        .phase_o            (derotator_test_vif.phase_o),
        .freq_word_o        (derotator_test_vif.freq_word_o)
    );

    // =========================================================================
    // FIXED BIND STATEMENT
    // Connect directly to the DUT's internal port names, NOT the interface.
    // =========================================================================
    bind derotator sva sva_inst (
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        .s_axis_valid_i    (s_axis_valid_i),
        .force_freq_en_i   (force_freq_en_i),
        .force_freq_i      (force_freq_i),
        .m_axis_valid_o    (m_axis_valid_o),
        .m_axis_i_sym_o    (m_axis_i_sym_o),
        .m_axis_q_sym_o    (m_axis_q_sym_o),
        .freq_word_o       (freq_word_o)
    );

    initial begin
        uvm_config_db#(virtual derotator_inter)::set(null, "*", "derotator_test_vif", derotator_test_vif);
        run_test("derotator_test");
    end
endmodule