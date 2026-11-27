`timescale 1ns/1ps
import costas_top_test_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"

module top ();
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #4 clk = ~clk;
    end

    costas_top_inter costas_top_test_vif (clk);
    assign costas_top_test_vif.rst_n = rst_n;

    initial begin
        rst_n = 0;
        #100 rst_n = 1;
        costas_top_test_vif.s_axis_valid_i = 0;
        costas_top_test_vif.s_axis_i_sym_i = 0;
        costas_top_test_vif.s_axis_q_sym_i = 0;
        costas_top_test_vif.mode_i = 0;
        costas_top_test_vif.preamble_end_i = 0;
        costas_top_test_vif.mod_type_i = 0;
        costas_top_test_vif.slicer_qpsk_i = 0;
        costas_top_test_vif.costas_gain_i = 0;
    end

    costas_top dut (
        .clk_i            (clk),
        .rst_ni           (rst_n),
        .s_axis_valid_i   (costas_top_test_vif.s_axis_valid_i),
        .s_axis_i_sym_i   (costas_top_test_vif.s_axis_i_sym_i),
        .s_axis_q_sym_i   (costas_top_test_vif.s_axis_q_sym_i),
        .mod_type_i       (costas_top_test_vif.mod_type_i),
        .costas_gain_i    (costas_top_test_vif.costas_gain_i),
        .mode_i           (costas_top_test_vif.mode_i),
        .slicer_qpsk_i    (costas_top_test_vif.slicer_qpsk_i),
        .preamble_end_i   (costas_top_test_vif.preamble_end_i),
        .freq_adj_valid_o (costas_top_test_vif.freq_adj_valid_o),
        .freq_adj_o       (costas_top_test_vif.freq_adj_o),
        .int_o            (costas_top_test_vif.int_o),
        .phase_adj_valid_o(costas_top_test_vif.phase_adj_valid_o),
        .phase_adj_o      (costas_top_test_vif.phase_adj_o),
        .quad_unresolved_o(costas_top_test_vif.quad_unresolved_o),
        .lock_o           (costas_top_test_vif.lock_o),
        .dbg_e_o          (costas_top_test_vif.dbg_e_o),
        .dbg_e_valid_o    (costas_top_test_vif.dbg_e_valid_o),
        .dbg_lock_int_o   (costas_top_test_vif.dbg_lock_int_o),
        .dbg_quad_done_o  (costas_top_test_vif.dbg_quad_done_o)
    );

    // Connect the SVA to the DUT
    bind costas_top sva sva_inst (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .lock_o               (lock_o),
        .dbg_quad_done_o      (dbg_quad_done_o),
        .dbg_quad_unresolved_o(quad_unresolved_o),
        .freq_adj_valid_o     (freq_adj_valid_o),
        .freq_adj_o           (freq_adj_o)
    );
    
    initial begin
        uvm_config_db#(virtual costas_top_inter)::set(null, "*", "costas_top_test_vif", costas_top_test_vif);
        run_test("costas_top_test");
    end
endmodule