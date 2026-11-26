`timescale 1ns/1ps

import coarse_cfo_core_test_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"

module top ();

  logic clk;

  // Clock: 50 MHz (20 ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Interface instance — rst_ni driven directly by UVM driver without multi-driver contention
  coarse_cfo_core_inter coarse_cfo_core_test_vif (clk);

  // Initialize interface signals cleanly at t=0
  initial begin
    coarse_cfo_core_test_vif.rst_ni         = 0;
    coarse_cfo_core_test_vif.start_i        = 0;
    coarse_cfo_core_test_vif.s_axis_valid_i = 0;
    coarse_cfo_core_test_vif.s_axis_i_sym_i = 0;
    coarse_cfo_core_test_vif.s_axis_q_sym_i = 0;
    coarse_cfo_core_test_vif.force_cfo_en_i = 0;
    coarse_cfo_core_test_vif.force_cfo_i    = 0;
  end

  // DUT — fully connected through interface
  coarse_cfo_core dut (
    .clk_i           (clk),
    .rst_ni          (coarse_cfo_core_test_vif.rst_ni),
    .start_i         (coarse_cfo_core_test_vif.start_i),
    .s_axis_valid_i  (coarse_cfo_core_test_vif.s_axis_valid_i),
    .s_axis_i_sym_i  (coarse_cfo_core_test_vif.s_axis_i_sym_i),
    .s_axis_q_sym_i  (coarse_cfo_core_test_vif.s_axis_q_sym_i),
    .m_axis_valid_o  (coarse_cfo_core_test_vif.m_axis_valid_o),
    .m_axis_cfo_o    (coarse_cfo_core_test_vif.m_axis_cfo_o),
    .force_cfo_en_i  (coarse_cfo_core_test_vif.force_cfo_en_i),
    .force_cfo_i     (coarse_cfo_core_test_vif.force_cfo_i)
  );

  // SVA bind
  bind coarse_cfo_core sva sva_inst (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .m_axis_valid_o (m_axis_valid_o),
    .m_axis_cfo_o   (m_axis_cfo_o)
  );

  // Pass VIF to UVM
  initial begin
    uvm_config_db#(virtual coarse_cfo_core_inter)::set(
      null, "*", "coarse_cfo_core_test_vif", coarse_cfo_core_test_vif);
    run_test("coarse_cfo_core_test");
  end

endmodule