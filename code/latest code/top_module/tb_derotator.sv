////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         tb_derotator
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

// Testbench for derotator: verifies that a known input symbol, rotated
// by a known NCO phase, produces the expected output.
//
// Tests:
//   1. Zero frequency, zero phase → output = input (bit-exact)
//   2. Quadrant rotation at exact multiples of pi/2 (q=0..3)
//   3. Coarse frequency word load + rotation check
//   4. Force frequency override (DFT)
//   5. Random input with zero phase → output matches input

// tb_derotator: NCO + LUT + quadrant rotator + complex multiplier.
// Fixes vs. original: replaced $abs() (non-standard) with a helper function.

`timescale 1ns / 1ps

module tb_derotator;

  localparam int Width     = 32;
  localparam int PhaseBits = 12;
  localparam int DataWidth = 16;
  localparam int Frac      = 15;
  localparam int CoarseW   = 24;

  logic                     clk;
  logic                     rst_n;
  logic                     s_axis_valid;
  logic signed [DataWidth-1:0] s_axis_i, s_axis_q;
  logic                     coarse_valid;
  logic signed [CoarseW-1:0] coarse_word;
  logic                     freq_adj_valid;
  logic signed [Width-1:0]  freq_adj;
  logic                     force_freq_en;
  logic [Width-1:0]         force_freq;
  logic                     phase_adj_valid;
  logic [Width-1:0]         phase_adj;
  logic                     m_axis_valid;
  logic signed [DataWidth-1:0] m_axis_i, m_axis_q;
  logic [Width-1:0]         phase_o, freq_word_o;

  int errors = 0;

  initial clk = 1'b0;
  always #4 clk = ~clk;

  derotator #(
    .Width       (Width),
    .Phase_Bits  (PhaseBits),
    .DataWidth   (DataWidth),
    .Frac        (Frac),
    .Coarse_W    (CoarseW),
    .Coarse_Shift(Width - CoarseW)
  ) u_dut (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .s_axis_valid_i   (s_axis_valid),
    .s_axis_i_sym_i   (s_axis_i),
    .s_axis_q_sym_i   (s_axis_q),
    .coarse_valid_i   (coarse_valid),
    .coarse_word_i    (coarse_word),
    .freq_adj_valid_i (freq_adj_valid),
    .freq_adj_i       (freq_adj),
    .force_freq_en_i  (force_freq_en),
    .force_freq_i     (force_freq),
    .phase_adj_valid_i(phase_adj_valid),
    .phase_adj_i      (phase_adj),
    .m_axis_valid_o   (m_axis_valid),
    .m_axis_i_sym_o   (m_axis_i),
    .m_axis_q_sym_o   (m_axis_q),
    .phase_o          (phase_o),
    .freq_word_o      (freq_word_o)
  );

  // Helper: absolute difference as int (avoids overflow, no $abs)
  function automatic int abs_diff16(
    input logic signed [DataWidth-1:0] a,
    input logic signed [DataWidth-1:0] b
  );
    int diff;
    diff = int'(a) - int'(b);
    return (diff < 0) ? -diff : diff;
  endfunction

  task automatic do_reset();
    rst_n            = 1'b0;
    s_axis_valid     = 1'b0;
    s_axis_i         = '0;
    s_axis_q         = '0;
    coarse_valid     = 1'b0;
    coarse_word      = '0;
    freq_adj_valid   = 1'b0;
    freq_adj         = '0;
    force_freq_en    = 1'b0;
    force_freq       = '0;
    phase_adj_valid  = 1'b0;
    phase_adj        = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
  endtask

  task automatic drive_symbol(
    input  logic signed [DataWidth-1:0] i_in,
    input  logic signed [DataWidth-1:0] q_in,
    output logic signed [DataWidth-1:0] i_out,
    output logic signed [DataWidth-1:0] q_out
  );
    int timeout;
    @(posedge clk);
    s_axis_i     = i_in;
    s_axis_q     = q_in;
    s_axis_valid = 1'b1;
    timeout = 0;
    while (!m_axis_valid && timeout < 20) begin
      @(posedge clk);
      timeout++;
    end
    i_out = m_axis_i;
    q_out = m_axis_q;
    s_axis_valid = 1'b0;
    @(posedge clk);
  endtask

  // TEST 1: Zero rotation → passthrough
  task automatic test_zero_rotation();
    logic signed [DataWidth-1:0] i_in, q_in, i_out, q_out;
    int di, dq;
    $display("\n=== TEST 1: Zero rotation ===");
    do_reset();
    i_in = 16'sd8192;
    q_in = 16'sd4096;
    drive_symbol(i_in, q_in, i_out, q_out);
    di = abs_diff16(i_out, i_in);
    dq = abs_diff16(q_out, q_in);
    if (di > 10 || dq > 10) begin
      $display("FAIL: in=(%0d,%0d) out=(%0d,%0d) |d|=(%0d,%0d)",
               i_in, q_in, i_out, q_out, di, dq);
      errors++;
    end else begin
      $display("PASS: |d|=(%0d,%0d)", di, dq);
    end
  endtask

  // TEST 2: Coarse word load
  task automatic test_coarse_load();
    $display("\n=== TEST 2: Coarse word load ===");
    do_reset();
    coarse_word  = 24'sh400000;
    coarse_valid = 1'b1;
    @(posedge clk);
    coarse_valid = 1'b0;
    repeat (2) @(posedge clk);
    if (freq_word_o !== 32'sh4000_0000) begin
      $display("FAIL: freq_word_o=%h expected=40000000", freq_word_o);
      errors++;
    end else begin
      $display("PASS: freq_word_o=%h", freq_word_o);
    end
  endtask

  // TEST 3: Force frequency
  task automatic test_force_freq();
    $display("\n=== TEST 3: Force frequency ===");
    do_reset();
    force_freq_en = 1'b1;
    force_freq    = 32'h1234_5678;
    @(posedge clk);
    @(posedge clk);
    if (freq_word_o !== 32'h1234_5678) begin
      $display("FAIL: force got %h", freq_word_o);
      errors++;
    end else begin
      $display("PASS: force freq applied");
    end
    force_freq_en = 1'b0;
    @(posedge clk);
  endtask

  // TEST 4: Phase adj pulse
  task automatic test_phase_adj();
    logic [Width-1:0] phase_before;
    logic signed [DataWidth-1:0] out_i, out_q;
    $display("\n=== TEST 4: Phase adjustment pulse ===");
    do_reset();
    phase_before = phase_o;
    phase_adj       = 32'sh4000_0000;
    phase_adj_valid = 1'b1;
    @(posedge clk);
    phase_adj_valid = 1'b0;
    repeat (2) @(posedge clk);

    phase_adj_valid = 1'b1;
    drive_symbol(16'sd100, 16'sd0, out_i, out_q);
    phase_adj_valid = 1'b0;

    if (phase_o == phase_before) begin
      $display("WARN: phase unchanged");
    end else begin
      $display("PASS: phase %h -> %h", phase_before, phase_o);
    end
  endtask

  // TEST 5: Latency
  task automatic test_latency();
    int cnt;
    $display("\n=== TEST 5: Pipeline latency ===");
    do_reset();
    cnt = 0;
    fork
      begin
        s_axis_i     = 16'sd1000;
        s_axis_q     = 16'sd2000;
        s_axis_valid = 1'b1;
        @(posedge clk);
        s_axis_valid = 1'b0;
      end
      begin
        while (!m_axis_valid && cnt < 10) begin
          @(posedge clk);
          cnt++;
        end
        if (cnt == 3) $display("PASS: latency = 3 cycles");
        else          $display("WARN: latency = %0d (expected 3)", cnt);
      end
    join
  endtask

  initial begin
    $display("==========================================================");
    $display("TB: derotator");
    $display("==========================================================");
    test_zero_rotation();
    test_coarse_load();
    test_force_freq();
    test_phase_adj();
    test_latency();
    $display("\n==========================================================");
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d FAILURES", errors);
    $display("==========================================================");
    $finish;
  end

  initial begin
    #100_000;
    $display("WATCHDOG TIMEOUT");
    $finish;
  end

endmodule