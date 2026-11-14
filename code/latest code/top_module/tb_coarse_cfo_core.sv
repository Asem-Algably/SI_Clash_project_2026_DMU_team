////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         tb_coarse_cfo_core
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

// tb_coarse_cfo_core: verifies the lag-4 correlator + CORDIC CFO estimator.
//
// Tests:
//   1. Zero CFO (DC input) → estimate near 0
//   2. +0.05 Rsym pure tone → estimate ≈ +838861 (0.05 × 2^24)
//   3. -0.05 Rsym pure tone → estimate ≈ -838861
//   4. Force override (DFT) → forced value passes through

`timescale 1ns / 1ps

module tb_coarse_cfo_core;

  localparam int DataWidth = 16;
  localparam int CoarseW   = 24;
  localparam int WinLen    = 32;
  localparam int Lag       = 4;

  localparam real PI_VAL   = 3.14159265358979;
  localparam int  AMPL_Q15 = 16384;    // 0.5 in Q1.15
  localparam int  TOLERANCE = 2000;    // ~0.012% Rsym

  logic                          clk;
  logic                          rst_n;
  logic                          start;
  logic                          s_axis_valid;
  logic signed [DataWidth-1:0]   s_axis_i, s_axis_q;
  logic                          m_axis_valid;
  logic signed [CoarseW-1:0]     m_axis_cfo;
  logic                          force_cfo_en;
  logic [CoarseW-1:0]            force_cfo;

  int errors = 0;
  logic signed [CoarseW-1:0] captured_cfo;
  logic captured_valid;
  int captured_latency;

  initial clk = 1'b0;
  always #4 clk = ~clk;

  coarse_cfo_core #(
    .DataWidth(DataWidth),
    .Lag      (Lag),
    .WinLen   (WinLen),
    .AccWidth (40)
  ) u_dut (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .start_i        (start),
    .s_axis_valid_i (s_axis_valid),
    .s_axis_i_sym_i (s_axis_i),
    .s_axis_q_sym_i (s_axis_q),
    .m_axis_valid_o (m_axis_valid),
    .m_axis_cfo_o   (m_axis_cfo),
    .force_cfo_en_i (force_cfo_en),
    .force_cfo_i    (force_cfo)
  );

  always_ff @(posedge clk) begin
    if (m_axis_valid) begin
      captured_cfo   <= m_axis_cfo;
      captured_valid <= 1'b1;
    end
  end

  function automatic int abs_diff24(
    input logic signed [CoarseW-1:0] a,
    input logic signed [CoarseW-1:0] b
  );
    int diff;
    diff = int'(a) - int'(b);
    return (diff < 0) ? -diff : diff;
  endfunction

  task automatic drive_symbol(
    input logic signed [DataWidth-1:0] i_val,
    input logic signed [DataWidth-1:0] q_val
  );
    s_axis_i     = i_val;
    s_axis_q     = q_val;
    s_axis_valid = 1'b1;
    @(posedge clk);
    s_axis_valid = 1'b0;
    repeat (3) @(posedge clk);
  endtask

  // Generic test: feed 32-symbol tone with given CFO
  task automatic test_cfo(
    input real cfo_rsym,
    input int  expected_word,
    input string msg
  );
    real phase;
    real dphase;
    real two_pi;
    real ci;
    real si;
    int  i_q15, q_q15;
    int  diff;
    int  timeout;

    $display("\n=== %s ===", msg);
    $display("  Target CFO = %0.4f Rsym, expected word = %0d",
             cfo_rsym, expected_word);

    // Reset
    rst_n          = 1'b0;
    start          = 1'b0;
    s_axis_valid   = 1'b0;
    s_axis_i       = '0;
    s_axis_q       = '0;
    force_cfo_en   = 1'b0;
    force_cfo      = '0;
    captured_valid = 1'b0;
    captured_cfo   = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // Start correlation
    start = 1'b1;
    @(posedge clk);

    // Feed 32 symbols with known CFO (pure tone)
    two_pi = 2.0 * PI_VAL;
    dphase = two_pi * cfo_rsym;
    phase  = 0.0;

    for (int n = 0; n < WinLen; n++) begin
      ci    = $cos(phase);
      si    = $sin(phase);
      i_q15 = $rtoi(ci * AMPL_Q15);
      q_q15 = $rtoi(si * AMPL_Q15);
      drive_symbol(i_q15[DataWidth-1:0], q_q15[DataWidth-1:0]);
      phase = phase + dphase;
      if (phase > two_pi) phase = phase - two_pi;
      if (phase < 0.0)    phase = phase + two_pi;
    end

    // Wait for output (up to 30 cycles for CORDIC + pipeline)
    timeout = 0;
    while (!captured_valid && timeout < 30) begin
      @(posedge clk);
      timeout++;
    end

    if (!captured_valid) begin
      $display("  FAIL: m_axis_valid_o did not assert within 30 cycles");
      errors++;
      return;
    end

    $display("  Captured word  = %0d (0x%06h)", captured_cfo, captured_cfo);
    $display("  Latency        = %0d cycles", timeout);

    diff = abs_diff24(captured_cfo, CoarseW'(expected_word));
    $display("  |diff|         = %0d LSB (tol %0d)", diff, TOLERANCE);

    if (diff > TOLERANCE) begin
      $display("  FAIL: CFO error too large");
      errors++;
    end else begin
      $display("  PASS: CFO within tolerance");
    end

    start = 1'b0;
    @(posedge clk);
  endtask

  // TEST 4: Force override
  task automatic test_force_override();
    logic [CoarseW-1:0] forced_val;
    $display("\n=== TEST 4: Force override ===");

    rst_n          = 1'b0;
    start          = 1'b0;
    s_axis_valid   = 1'b0;
    force_cfo_en   = 1'b0;
    force_cfo      = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    forced_val   = 24'h12_3456;
    force_cfo_en = 1'b1;
    force_cfo    = forced_val;
    @(posedge clk);
    @(posedge clk);

    if (m_axis_cfo !== forced_val) begin
      $display("  FAIL: got 0x%06h, expected 0x%06h", m_axis_cfo, forced_val);
      errors++;
    end else begin
      $display("  PASS: forced value applied");
    end

    force_cfo_en = 1'b0;
    @(posedge clk);
  endtask

  initial begin
    $display("==========================================================");
    $display("TB: coarse_cfo_core");
    $display("==========================================================");

    test_cfo(0.0,   0,         "TEST 1: Zero CFO");
    test_cfo(+0.05, 838861,    "TEST 2: CFO = +0.05 Rsym");
    test_cfo(-0.05, -838861,   "TEST 3: CFO = -0.05 Rsym");
    test_force_override();

    $display("\n==========================================================");
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d FAILURES", errors);
    $display("==========================================================");
    $finish;
  end

  initial begin
    #500_000;
    $display("WATCHDOG TIMEOUT");
    $finish;
  end

endmodule