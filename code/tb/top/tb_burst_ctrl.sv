////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         tb_burst_ctrl
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

// Testbench for burst_ctrl: verifies the acquisition FSM transitions
// (WaitBurst -> Acquire -> CoarseEst -> Load -> CostasAcq -> Track),
// the timeout paths, and the preamble_end pulse.
//
// Tests:
//   1. Reset state is WaitBurst
//   2. Normal path with str_lock and coarse_valid arriving early
//   3. Timeout path where str_lock never asserts (NA1 timeout)
//   4. Preamble end pulse is exactly 1 cycle wide
//   5. Costas mode is HOLD during Acquire/CoarseEst/Load, ACQ during
//      CostasAcq, TRACK in Track

//   - Test 3: assertion corrected (CoarseEst timeout leads to CostasAcq
//     via Load within NA2+5 strobes, not to Load)
//   - Test 4: uses fork/join_any to monitor preamble_end pulse while
//     driving symbols (previous version hung on the while loop)

`timescale 1ns / 1ps

module tb_burst_ctrl;

  localparam int unsigned NA1       = 70;
  localparam int unsigned NA2       = 40;
  localparam int unsigned NPreamble = 190;

  localparam logic [2:0] StWaitBurst = 3'd0;
  localparam logic [2:0] StAcquire   = 3'd1;
  localparam logic [2:0] StCoarseEst = 3'd2;
  localparam logic [2:0] StLoad      = 3'd3;
  localparam logic [2:0] StCostasAcq = 3'd4;
  localparam logic [2:0] StTrack     = 3'd5;

  localparam logic [1:0] CostasHold  = 2'b00;
  localparam logic [1:0] CostasAcq   = 2'b01;
  localparam logic [1:0] CostasTrack = 2'b10;

  logic       clk;
  logic       rst_n;
  logic       start_of_burst;
  logic       str_lock;
  logic       coarse_valid;
  logic       sym_strobe;
  logic       coarse_start;
  logic [1:0] costas_mode;
  logic       preamble_end;
  logic [2:0] state;

  int errors = 0;

  initial clk = 1'b0;
  always #4 clk = ~clk;

  burst_ctrl #(
    .NA1        (NA1),
    .NA2        (NA2),
    .NPreamble  (NPreamble),
    .CostasHold (CostasHold),
    .CostasAcq  (CostasAcq),
    .CostasTrack(CostasTrack)
  ) u_dut (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .start_of_burst_i(start_of_burst),
    .str_lock_i     (str_lock),
    .coarse_valid_i (coarse_valid),
    .sym_strobe_i   (sym_strobe),
    .coarse_start_o (coarse_start),
    .costas_mode_o  (costas_mode),
    .preamble_end_o (preamble_end),
    .state_o        (state)
  );

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  task automatic assert_state(input logic [2:0] expected, input string msg);
    if (state !== expected) begin
      $display("[%0t] FAIL: %s — state=%0d expected=%0d",
               $time, msg, state, expected);
      errors++;
    end
  endtask

  task automatic assert_costas_mode(input logic [1:0] expected, input string msg);
    if (costas_mode !== expected) begin
      $display("[%0t] FAIL: %s — costas_mode=%0b expected=%0b",
               $time, msg, costas_mode, expected);
      errors++;
    end
  endtask

  task automatic drive_symbols(input int n);
    repeat (n) begin
      sym_strobe = 1'b1;
      @(posedge clk);
      sym_strobe = 1'b0;
      @(posedge clk);
    end
  endtask

  task automatic do_reset();
    rst_n          = 1'b0;
    start_of_burst = 1'b0;
    str_lock       = 1'b0;
    coarse_valid   = 1'b0;
    sym_strobe     = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask

  // -------------------------------------------------------------------------
  // TEST 1: Reset state
  // -------------------------------------------------------------------------
  task automatic test_reset_state();
    $display("\n=== TEST 1: Reset state ===");
    do_reset();
    assert_state(StWaitBurst, "after reset");
    assert_costas_mode(CostasHold, "Costas at reset");
    $display("Test 1 PASS");
  endtask

  // -------------------------------------------------------------------------
  // TEST 2: Normal acquisition path (str_lock + coarse_valid arrive on time)
  // -------------------------------------------------------------------------
  task automatic test_normal_path();
    $display("\n=== TEST 2: Normal acquisition path ===");
    do_reset();

    start_of_burst = 1'b1;
    @(posedge clk);
    start_of_burst = 1'b0;
    @(posedge clk);
    assert_state(StAcquire, "after start_of_burst");
    assert_costas_mode(CostasHold, "HOLD in Acquire");

    drive_symbols(20);
    str_lock = 1'b1;
    @(posedge clk);
    @(posedge clk);
    assert_state(StCoarseEst, "after str_lock");
    if (coarse_start !== 1'b1) begin
      $display("[%0t] FAIL: coarse_start not asserted", $time);
      errors++;
    end

    drive_symbols(32);
    if (coarse_start !== 1'b1) begin
      $display("[%0t] FAIL: coarse_start deasserted early", $time);
      errors++;
    end

    coarse_valid = 1'b1;
    @(posedge clk);
    coarse_valid = 1'b0;
    @(posedge clk);
    assert_state(StLoad, "after coarse_valid");
    if (coarse_start !== 1'b0) begin
      $display("[%0t] FAIL: coarse_start still high in Load", $time);
      errors++;
    end

    drive_symbols(1);
    assert_state(StCostasAcq, "entered CostasAcq");
    assert_costas_mode(CostasAcq, "ACQ in CostasAcq");

    // Drive the rest of the preamble, monitoring preamble_end in parallel
    fork
      begin
        drive_symbols(NPreamble);   // generous margin
      end
      begin : monitor_pulse
        while (preamble_end !== 1'b1) @(posedge clk);
        $display("[%0t] INFO: preamble_end pulsed", $time);
        disable monitor_pulse;
      end
    join_any
    disable fork;
    @(posedge clk);
    @(posedge clk);
    assert_state(StTrack, "entered Track");
    assert_costas_mode(CostasTrack, "TRACK in Track");
    $display("Test 2 PASS");
  endtask

  // -------------------------------------------------------------------------
  // TEST 3: Timeout path (no str_lock, no coarse_valid)
  // -------------------------------------------------------------------------
  task automatic test_timeout_path();
    $display("\n=== TEST 3: Timeout path ===");
    do_reset();

    start_of_burst = 1'b1;
    @(posedge clk);
    start_of_burst = 1'b0;
    @(posedge clk);

    // Acquire → CoarseEst at symbol 70 (NA1 timeout)
    drive_symbols(NA1 + 5);
    assert_state(StCoarseEst, "timeout to CoarseEst");

    // CoarseEst → Load at symbol 110 (NA1+NA2 timeout), then Load → CostasAcq
    // at symbol 111 (1 strobe). By symbol 120 (after NA2+5 strobes) we are
    // in CostasAcq, NOT Load.
    drive_symbols(NA2 + 5);
    assert_state(StCostasAcq, "timeout to CostasAcq (via Load)");
    assert_costas_mode(CostasAcq, "ACQ after timeouts");
    $display("Test 3 PASS");
  endtask

  // -------------------------------------------------------------------------
  // TEST 4: preamble_end pulse width (exactly 1 cycle)
  // -------------------------------------------------------------------------
  task automatic test_preamble_end_pulse_width();
    int pwidth;
    $display("\n=== TEST 4: preamble_end pulse width ===");

    // Continue from Test 3: currently in CostasAcq
    assert_state(StCostasAcq, "still in CostasAcq");

    fork
      begin
        drive_symbols(NPreamble);   // generous; will be killed on pulse
      end
      begin
        // Wait for the rising edge
        while (preamble_end !== 1'b1) @(posedge clk);
        // Count how many cycles it stays high
        pwidth = 0;
        while (preamble_end === 1'b1) begin
          pwidth++;
          @(posedge clk);
        end
        if (pwidth != 1) begin
          $display("[%0t] FAIL: preamble_end width=%0d, expected 1", $time, pwidth);
          errors++;
        end else begin
          $display("[%0t] PASS: preamble_end width = 1 cycle", $time);
        end
        disable fork;
      end
    join
    @(posedge clk);
    @(posedge clk);
    assert_state(StTrack, "entered Track after pulse");
    $display("Test 4 PASS");
  endtask

  // -------------------------------------------------------------------------
  // Main
  // -------------------------------------------------------------------------
  initial begin
    $display("==========================================================");
    $display("TB: burst_ctrl");
    $display("==========================================================");

    test_reset_state();
    test_normal_path();
    test_timeout_path();
    test_preamble_end_pulse_width();

    $display("\n==========================================================");
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d FAILURES", errors);
    $display("==========================================================");
    $finish;
  end

  initial begin
    #5_000_000;
    $display("WATCHDOG TIMEOUT");
    $finish;
  end

endmodule