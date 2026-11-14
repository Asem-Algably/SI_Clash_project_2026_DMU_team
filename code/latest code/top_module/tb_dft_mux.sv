////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         tb_dft_mux
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

// Testbench for dft_mux: verifies all 16 channels route the correct
// observation data, and that the default channel (channel 15) is
// selected when dft_sel > 14 is unused.

`timescale 1ns / 1ps

module tb_dft_mux;

  logic [3:0]              dft_sel;
  logic [15:0][31:0]       obs_data;
  logic [31:0]             dft_obs_data;

  int errors = 0;

  // DUT
  dft_mux #(
    .NumChannels(16),
    .DataWidth  (32),
    .DftSelWidth(4)
  ) u_dut (
    .dft_sel_i     (dft_sel),
    .obs_data_i    (obs_data),
    .dft_obs_data_o(dft_obs_data)
  );

  // ==========================================================================
  // Test
  // ==========================================================================
  initial begin
    $display("==========================================================");
    $display("TB: dft_mux");
    $display("==========================================================");

    // Fill the observation bus with unique patterns
    for (int i = 0; i < 16; i++) begin
      obs_data[i] = 32'hA000_0000 | i;
    end

    // Sweep all 16 channels
    for (int i = 0; i < 16; i++) begin
      dft_sel = i[3:0];
      #1;
      if (dft_obs_data !== (32'hA000_0000 | i)) begin
        $display("FAIL: ch%0d expected=%h got=%h",
                 i, 32'hA000_0000 | i, dft_obs_data);
        errors++;
      end else begin
        $display("PASS: ch%0d = %h", i, dft_obs_data);
      end
    end

    // ======================================================================
    // Random pattern check
    // ======================================================================
    $display("\n--- Randomized sweep ---");
    for (int trial = 0; trial < 100; trial++) begin
      for (int i = 0; i < 16; i++) obs_data[i] = $urandom;
      dft_sel = $urandom;
      #1;
      if (dft_obs_data !== obs_data[dft_sel]) begin
        $display("FAIL: random ch%0d mismatch", dft_sel);
        errors++;
      end
    end
    if (errors == 0) $display("Random sweep PASS");

    $display("\n==========================================================");
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d FAILURES", errors);
    $display("==========================================================");
    $finish;
  end

endmodule