`timescale 1ns/1ps

module top ();
    import uvm_pkg::*;
    import str_top_test_pkg::*;
    `include "uvm_macros.svh"

    logic clk;

    // 125 MHz clock
    initial begin
        clk = 1'b0;
        forever #4 clk = ~clk;
    end

    // Interface. rst_n is driven by the UVM driver (reset_seq) through this interface.
    str_top_inter str_top_test_vif (clk);

    // DUT (unchanged)
    str_top dut (
        .clk_i            (clk),
        .rst_ni           (str_top_test_vif.rst_n),
        .s_axis_valid_i   (str_top_test_vif.s_axis_valid_i),
        .flush_active_i   (str_top_test_vif.flush_active_i),
        .s_axis_i_sample_i(str_top_test_vif.s_axis_i_sample_i),
        .s_axis_q_sample_i(str_top_test_vif.s_axis_q_sample_i),
        .loop_gain_i      (str_top_test_vif.loop_gain_i),
        .m_axis_valid_o   (str_top_test_vif.m_axis_valid_o),
        .m_axis_i_sym_o   (str_top_test_vif.m_axis_i_sym_o),
        .m_axis_q_sym_o   (str_top_test_vif.m_axis_q_sym_o),
        .lock_o           (str_top_test_vif.lock_o),
        .ted_err_valid_o  (str_top_test_vif.ted_err_valid_o),
        .ted_err_o        (str_top_test_vif.ted_err_o),
        .mu_o             (str_top_test_vif.mu_o),
        .w_o              (str_top_test_vif.w_o),
        .force_w_en_i     (str_top_test_vif.force_w_en_i),
        .force_w_i        (str_top_test_vif.force_w_i)
    );

    initial begin
        uvm_config_db#(virtual str_top_inter)::set(null, "*", "str_top_test_vif", str_top_test_vif);
        run_test("str_top_test");
    end
endmodule
