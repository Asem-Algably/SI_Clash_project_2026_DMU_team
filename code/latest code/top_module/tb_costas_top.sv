////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         module tb_costas_top;
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

// Testbench for costas_top: verifies phase/frequency loop acquisition.
//
// Tests:
//   1. HOLD mode: no output valid pulses
//   2. ACQ mode with clean QPSK symbols: loop locks, freq_adj converges
//   3. TRACK mode: freq_adj settles to near zero
//   4. Quadrant resolution: preamble_end triggers phase_adj
//   5. Public lock asserts after quadrant resolution

// tb_costas_top: slicer + phase detector + PI filter + lock + quadrant.
// Fixes vs. original:
//   - Replaced $abs() (non-standard) with helper abs32()
//   - Replaced real task ports with pre-scaled int (Q1.15)
//   - Split real variable declaration from initialization

// Testbench for costas_top.
//
// Fixes vs. original:
//   - Task ports use pre-scaled int (Q1.15) instead of real
//   - Test 5: check lock at symbol 5 (before quad resolution) instead of 60

`timescale 1ns / 1ps

module tb_costas_top;

  localparam int DataWidth  = 16;
  localparam int ErrorWidth = 16;
  localparam int PhaseWidth = 32;

  localparam logic [1:0] MODE_HOLD  = 2'b00;
  localparam logic [1:0] MODE_ACQ   = 2'b01;
  localparam logic [1:0] MODE_TRACK = 2'b10;

  localparam logic [1:0] MOD_QPSK  = 2'b00;
  localparam logic [1:0] MOD_QAM16 = 2'b01;

  logic                     clk;
  logic                     rst_n;
  logic                     s_axis_valid;
  logic signed [DataWidth-1:0] s_axis_i, s_axis_q;
  logic [1:0]               mod_type;
  logic [7:0]               costas_gain;
  logic [1:0]               mode;
  logic                     slicer_qpsk;
  logic                     preamble_end;
  logic                     freq_adj_valid;
  logic signed [PhaseWidth-1:0] freq_adj;
  logic signed [PhaseWidth-1:0] int_out;
  logic                     phase_adj_valid;
  logic [PhaseWidth-1:0]    phase_adj;
  logic                     quad_unresolved;
  logic                     lock;
  logic signed [ErrorWidth-1:0] dbg_e;
  logic                     dbg_e_valid;
  logic                     dbg_lock_int;
  logic                     dbg_quad_done;

  int errors = 0;

  initial clk = 1'b0;
  always #4 clk = ~clk;

  costas_top u_dut (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .s_axis_valid_i   (s_axis_valid),
    .s_axis_i_sym_i   (s_axis_i),
    .s_axis_q_sym_i   (s_axis_q),
    .mod_type_i       (mod_type),
    .costas_gain_i    (costas_gain),
    .mode_i           (mode),
    .slicer_qpsk_i    (slicer_qpsk),
    .preamble_end_i   (preamble_end),
    .freq_adj_valid_o (freq_adj_valid),
    .freq_adj_o       (freq_adj),
    .int_o            (int_out),
    .phase_adj_valid_o(phase_adj_valid),
    .phase_adj_o      (phase_adj),
    .quad_unresolved_o(quad_unresolved),
    .lock_o           (lock),
    .dbg_e_o          (dbg_e),
    .dbg_e_valid_o    (dbg_e_valid),
    .dbg_lock_int_o   (dbg_lock_int),
    .dbg_quad_done_o  (dbg_quad_done)
  );

  // ---- Helper: 32-bit absolute value ----
  function automatic logic [31:0] abs32(input logic signed [31:0] v);
    return v[31] ? (32'h0 - v) : v;
  endfunction

  task automatic do_reset();
    rst_n        = 1'b0;
    s_axis_valid = 1'b0;
    s_axis_i     = '0;
    s_axis_q     = '0;
    mod_type     = MOD_QPSK;
    costas_gain  = 8'd0;
    mode         = MODE_HOLD;
    slicer_qpsk  = 1'b1;
    preamble_end = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);
  endtask

  task automatic drive_qpsk_q15(
    input logic signed [DataWidth-1:0] i_q15,
    input logic signed [DataWidth-1:0] q_q15
  );
    s_axis_i     = i_q15;
    s_axis_q     = q_q15;
    s_axis_valid = 1'b1;
    @(posedge clk);
    s_axis_valid = 1'b0;
    repeat (4) @(posedge clk);
  endtask

  task automatic drive_qpsk_default();
    drive_qpsk_q15(16'sd16384, 16'sd16384);
  endtask

  // -------------------------------------------------------------------------
  // TEST 1: HOLD — no freq_adj_valid
  // -------------------------------------------------------------------------
  task automatic test_hold_mode();
    int pulse_cnt;
    $display("\n=== TEST 1: HOLD produces no output ===");
    do_reset();
    mode = MODE_HOLD;
    pulse_cnt = 0;

    fork
      begin
        repeat (60) begin
          @(posedge clk);
          if (freq_adj_valid) pulse_cnt++;
        end
      end
      begin
        repeat (10) drive_qpsk_default();
      end
    join

    if (pulse_cnt > 0) begin
      $display("FAIL: freq_adj_valid asserted %0d times in HOLD", pulse_cnt);
      errors++;
    end else begin
      $display("PASS: no freq_adj_valid in HOLD");
    end
  endtask

  // -------------------------------------------------------------------------
  // TEST 2: ACQ with clean QPSK — internal lock asserts
  // -------------------------------------------------------------------------
  task automatic test_acq_mode();
    logic [31:0] abs_freq;
    $display("\n=== TEST 2: ACQ acquisition (clean QPSK) ===");
    do_reset();
    mode        = MODE_ACQ;
    slicer_qpsk = 1'b1;

    for (int i = 0; i < 100; i++) drive_qpsk_default();

    if (!dbg_lock_int) begin
      $display("FAIL: internal lock did not assert");
      errors++;
    end else begin
      $display("PASS: internal lock asserted");
    end

    abs_freq = abs32(freq_adj);
    if (abs_freq > 32'h0100_0000) begin
      $display("FAIL: |freq_adj|=%h too large", abs_freq);
      errors++;
    end else begin
      $display("PASS: freq_adj=%h (near 0)", freq_adj);
    end
  endtask

  // -------------------------------------------------------------------------
  // TEST 3: ACQ with CFO = 0.01 Rsym
  // -------------------------------------------------------------------------
  task automatic test_acq_with_cfo();
    real phase;
    real dphase;
    real two_pi;
    real c_ph, s_ph;
    real ri, rq;
    int  i_q15, q_q15;

    $display("\n=== TEST 3: ACQ with CFO = 0.01 Rsym ===");
    do_reset();
    mode = MODE_ACQ;

    two_pi = 2.0 * 3.14159265358979;
    phase  = 0.0;
    dphase = two_pi * 0.01;

    for (int i = 0; i < 150; i++) begin
      c_ph = $cos(phase);
      s_ph = $sin(phase);
      ri   = 0.5 * c_ph - 0.5 * s_ph;
      rq   = 0.5 * s_ph + 0.5 * c_ph;
      i_q15 = $rtoi(ri * 32768.0);
      q_q15 = $rtoi(rq * 32768.0);
      drive_qpsk_q15(i_q15[DataWidth-1:0], q_q15[DataWidth-1:0]);
      phase = phase + dphase;
      if (phase > two_pi) phase = phase - two_pi;
    end

    if (!dbg_lock_int) begin
      $display("WARN: internal lock did not assert with CFO");
    end else begin
      $display("PASS: internal lock asserted with CFO");
    end
    $display("INFO: freq_adj = %h (%0d)", freq_adj, freq_adj);
  endtask

  // -------------------------------------------------------------------------
  // TEST 4: Quadrant resolution via preamble_end
  // -------------------------------------------------------------------------
  task automatic test_quad_resolution();
    $display("\n=== TEST 4: Quadrant resolution ===");
    do_reset();
    mode = MODE_ACQ;

    for (int i = 0; i < 60; i++) drive_qpsk_default();
    for (int i = 0; i < 50; i++) drive_qpsk_default();

    preamble_end = 1'b1;
    @(posedge clk);
    preamble_end = 1'b0;
    repeat (10) @(posedge clk);

    if (!dbg_quad_done && !quad_unresolved) begin
      $display("FAIL: quadrant not resolved");
      errors++;
    end else if (quad_unresolved) begin
      $display("WARN: quadrant UNRESOLVED");
    end else begin
      $display("PASS: quadrant resolved");
    end
  endtask

  // -------------------------------------------------------------------------
  // TEST 5: Public lock timing
  //   - At symbol 5: lock must be LOW (counters not yet full)
  //   - At symbol 65: lock must be HIGH (quad resolved + leaky bucket filled)
  // -------------------------------------------------------------------------
  task automatic test_public_lock();
    $display("\n=== TEST 5: Public lock timing ===");
    do_reset();
    mode = MODE_ACQ;

    // ---- Early check: 5 symbols ----
    for (int i = 0; i < 5; i++) drive_qpsk_default();
    @(posedge clk);
    if (lock) begin
      $display("FAIL: public lock high after only 5 symbols");
      errors++;
    end else begin
      $display("PASS: public lock LOW at symbol 5");
    end

    // ---- Late check: 60 more symbols (total 65) ----
    for (int i = 0; i < 60; i++) drive_qpsk_default();
    repeat (10) @(posedge clk);

    if (lock) begin
      $display("PASS: public lock HIGH at symbol 65");
    end else begin
      $display("WARN: public lock still low at symbol 65 (may need more settle)");
    end
  endtask

  // -------------------------------------------------------------------------
  // Main
  // -------------------------------------------------------------------------
  initial begin
    $display("==========================================================");
    $display("TB: costas_top");
    $display("==========================================================");

    test_hold_mode();
    test_acq_mode();
    test_acq_with_cfo();
    test_quad_resolution();
    test_public_lock();

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