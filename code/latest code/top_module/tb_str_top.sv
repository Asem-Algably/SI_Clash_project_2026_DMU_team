////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         tb_str_top
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////


// tb_str_top: standalone STR test (before integration).
//
// Feeds 800 input samples (200 QPSK symbols × 4 sps) at a constant rate.
// Expects ~200 output symbols with valid pulses.
//
// If this TB fails:
//   - STR is broken internally → debug top.sv
// If this TB passes but tb_sync_system_top fails:
//   - Integration issue → check connections, reset, or scaling

`timescale 1ns / 1ps

module tb_str_top;

  localparam int NumSamples = 800;
  localparam int Sps        = 4;
  localparam int ExpectedSyms = NumSamples / Sps;   // 200

  logic                clk = 1'b0;
  logic                rst_n;
  logic                in_valid;
  logic signed [11:0]  in_i, in_q;

  logic                out_valid;
  logic signed [15:0]  out_i, out_q;
  logic                lock_o;
  logic                ted_err_valid;
  logic signed [31:0]  ted_err_o;
  logic [9:0]          mu_o;
  logic [15:0]         w_o;

  int in_valid_cnt  = 0;
  int out_valid_cnt = 0;

  always #4 clk = ~clk;

  str_top u_str (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .s_axis_valid_i   (in_valid),
    .s_axis_i_sample_i(in_i),
    .s_axis_q_sample_i(in_q),
    .loop_gain_i      (8'd0),
    .m_axis_valid_o   (out_valid),
    .m_axis_i_sym_o   (out_i),
    .m_axis_q_sym_o   (out_q),
    .lock_o           (lock_o),
    .ted_err_valid_o  (ted_err_valid),
    .ted_err_o        (ted_err_o),
    .mu_o             (mu_o),
    .w_o              (w_o),
    .force_w_en_i     (1'b0),
    .force_w_i        (16'd0)
  );

  always_ff @(posedge clk) begin
    if (in_valid)  in_valid_cnt  <= in_valid_cnt + 1;
    if (out_valid) out_valid_cnt <= out_valid_cnt + 1;
  end

  // Print first 10 output symbols for debug
  always_ff @(posedge clk) begin
    if (out_valid && out_valid_cnt < 10) begin
      $display("[%0t] OUT #%0d: (%0d, %0d) mu=%0d W=%0d lock=%0b",
               $time, out_valid_cnt, out_i, out_q, mu_o, $signed(w_o), lock_o);
    end
  end

  initial begin
    $display("==========================================================");
    $display("TB: str_top (standalone)");
    $display("==========================================================");

    rst_n    = 1'b0;
    in_valid = 1'b0;
    in_i     = '0;
    in_q     = '0;
    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    // Drive alternating QPSK symbols every 4 samples
    // Pattern: Q1 = (+,+), Q4 = (+,-), Q1, Q4, ... (matches preamble phase A1)
    // Q1.11 amplitude: 1447 (0.707 × 2047)
    $display("\nDriving %0d samples (%0d QPSK symbols @ %0d sps)...",
             NumSamples, ExpectedSyms, Sps);
    for (int k = 0; k < NumSamples; k++) begin
      if ((k / Sps) % 2 == 0) begin
        // Q1 (preamble phase A1 even)
        in_i = 12'sd1447;
        in_q = 12'sd1447;
      end else begin
        // Q4 (preamble phase A1 odd)
        in_i = 12'sd1447;
        in_q = -12'sd1447;
      end
      in_valid = 1'b1;
      @(posedge clk);
      in_valid = 1'b0;
      repeat (Sps - 1) @(posedge clk);
    end

    // Drain
    repeat (200) @(posedge clk);

    $display("\n==========================================================");
    $display("RESULTS");
    $display("==========================================================");
    $display("  Input valid pulses  : %0d", in_valid_cnt);
    $display("  Output valid pulses : %0d", out_valid_cnt);
    $display("  STR lock            : %0b", lock_o);
    $display("  W (loop filter)     : %0d (hex %h)", $signed(w_o), w_o);
    $display("  mu (last)           : %0d", mu_o);
    $display("  Last TED error      : %0d", $signed(ted_err_o));

    // Sanity check
    if (out_valid_cnt < 100) begin
      $display("\nFAIL: only %0d output symbols (expected ~%0d)",
               out_valid_cnt, ExpectedSyms);
      $display("     STR is broken. Debug str_top.sv with waves.");
    end else if (out_valid_cnt > ExpectedSyms + 50) begin
      $display("\nWARN: %0d output symbols (more than expected %0d)",
               out_valid_cnt, ExpectedSyms);
      $display("     STR may be emitting extra strobes.");
    end else begin
      $display("\nPASS: %0d output symbols (~%0d expected)",
               out_valid_cnt, ExpectedSyms);
    end

    if (lock_o) begin
      $display("PASS: STR lock asserted");
    end else begin
      $display("WARN: STR lock never asserted (may need more symbols or tuning)");
    end

    $display("==========================================================");
    $finish;
  end

  initial begin
    #5_000_000;
    $display("WATCHDOG TIMEOUT");
    $finish;
  end

endmodule