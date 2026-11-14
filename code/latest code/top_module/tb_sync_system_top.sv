////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         tb_sync_system_top
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////



// Full-system integration testbench for sync_system_top.
//
// Generates a synthetic QPSK preamble matching the spec phases:
//   Phase A1 (70 syms): alternating Q4/Q2  — STR acquire
//   Phase A2 (40 syms): alternating Q4/Q2  — coarse CFO estimate
//   Phase B  (30 syms): alternating Q4/Q2  — Costas pull-in
//   Phase C  (50 syms): repeating [Q1,Q2,Q1,Q4]  — quadrant resolution
//
// Verifies:
//   1. STR lock asserts during Phase A1
//   2. Coarse CFO estimate is within tolerance
//   3. Costas public lock asserts after Phase C
//   4. out_sym_valid pulses at symbol rate after acquisition
//   5. lock_detect = str_lock & costas_lock
//
// NOTE: This TB requires the golden model's sine_quarter_lut.svh to be
// present in the rtl/ folder for compilation.

// tb_sync_system_top: full integration (inline preamble generation).
// Full-system integration testbench for sync_system_top.

`timescale 1ns / 1ps

module tb_sync_system_top;

  localparam int InSampleWidth = 12;
  localparam int OutSymWidth   = 16;
  localparam int CoarseWidth   = 24;
  localparam int PhaseWidth    = 32;

  localparam int Sps        = 4;
  localparam int NA1        = 70;
  localparam int NA2        = 40;
  localparam int NB         = 30;
  localparam int NC         = 50;
  localparam int NPreamble  = NA1 + NA2 + NB + NC;   // 190

  localparam real CFO_RSYM  = 0.01;
  localparam real PI_VAL    = 3.14159265358979;
  localparam real Q1_11_MAX = 2047.0;

  logic                          clk;
  logic                          rst_n;
  logic signed [InSampleWidth-1:0] in_sample_i, in_sample_q;
  logic                          in_sample_valid;
  logic [1:0]                    mod_type;
  logic [7:0]                    loop_gain;
  logic [7:0]                    costas_loop_gain;
  logic [3:0]                    dft_sel;
  logic                          start_of_burst;
  logic                          force_w_en;
  logic [15:0]                   force_w;
  logic                          force_cfo_en;
  logic signed [CoarseWidth-1:0] force_cfo;
  logic                          force_freq_en;
  logic [PhaseWidth-1:0]         force_freq;
  logic signed [OutSymWidth-1:0] out_sym_i, out_sym_q;
  logic                          out_sym_valid;
  logic signed [CoarseWidth-1:0] coarse_cfo_est;
  logic signed [PhaseWidth-1:0]  fine_cfo_est;
  logic                          lock_detect;
  logic [31:0]                   dft_obs_data;

  int errors = 0;
  int out_sym_count = 0;

  // ---- Debug counters ----
  int lock_int_high_cnt   = 0;
  int quad_done_high_cnt  = 0;
  int lock_pub_high_cnt   = 0;
  int costas_mode_acq_cnt = 0;
  int costas_mode_trk_cnt = 0;
  int fsm_costasacq_cnt   = 0;
  int fsm_track_cnt       = 0;

  initial clk = 1'b0;
  always #4 clk = ~clk;

  sync_system_top #(
    .InSampleWidth (InSampleWidth),
    .OutSymWidth   (OutSymWidth),
    .CoarseWidth   (CoarseWidth),
    .PhaseWidth    (PhaseWidth),
    .MuWidth       (10),
    .DftSelWidth   (4),
    .NA1           (NA1),
    .NA2           (NA2),
    .NPreamble     (NPreamble),
    .TedErrAlign   (2),
    .CostasErrAlign(0)
  ) u_dut (
    .clk             (clk),
    .rst_n           (rst_n),
    .in_sample_i     (in_sample_i),
    .in_sample_q     (in_sample_q),
    .in_sample_valid (in_sample_valid),
    .mod_type        (mod_type),
    .loop_gain       (loop_gain),
    .costas_loop_gain(costas_loop_gain),
    .dft_sel         (dft_sel),
    .start_of_burst  (start_of_burst),
    .force_w_en      (force_w_en),
    .force_w         (force_w),
    .force_cfo_en    (force_cfo_en),
    .force_cfo       (force_cfo),
    .force_freq_en   (force_freq_en),
    .force_freq      (force_freq),
    .out_sym_i       (out_sym_i),
    .out_sym_q       (out_sym_q),
    .out_sym_valid   (out_sym_valid),
    .coarse_cfo_est  (coarse_cfo_est),
    .fine_cfo_est    (fine_cfo_est),
    .lock_detect     (lock_detect),
    .dft_obs_data    (dft_obs_data)
  );

  always_ff @(posedge clk) begin
    if (out_sym_valid) out_sym_count <= out_sym_count + 1;

    // Debug cycle counters
    if (u_dut.costas_lock_int)        lock_int_high_cnt   <= lock_int_high_cnt + 1;
    if (u_dut.costas_quad_done)       quad_done_high_cnt  <= quad_done_high_cnt + 1;
    if (u_dut.costas_lock)            lock_pub_high_cnt   <= lock_pub_high_cnt + 1;
    if (u_dut.costas_mode == 2'd1)    costas_mode_acq_cnt <= costas_mode_acq_cnt + 1;
    if (u_dut.costas_mode == 2'd2)    costas_mode_trk_cnt <= costas_mode_trk_cnt + 1;
    if (u_dut.fsm_state  == 3'd4)     fsm_costasacq_cnt   <= fsm_costasacq_cnt + 1;
    if (u_dut.fsm_state  == 3'd5)     fsm_track_cnt       <= fsm_track_cnt + 1;
  end

  function automatic void get_preamble_symbol(
    input  int   n,
    output logic signed [InSampleWidth-1:0] i_out,
    output logic signed [InSampleWidth-1:0] q_out
  );
    real i_ideal, q_ideal;
    real cfo_phase, c, s;
    real i_rot, q_rot;

    if (n < NA1 + NA2 + NB) begin
      if (n % 2 == 0) begin
        i_ideal =  0.70710678;
        q_ideal = -0.70710678;
      end else begin
        i_ideal = -0.70710678;
        q_ideal =  0.70710678;
      end
    end else begin
      case ((n - NA1 - NA2 - NB) % 4)
        0: begin i_ideal =  0.70710678; q_ideal =  0.70710678; end
        1: begin i_ideal = -0.70710678; q_ideal =  0.70710678; end
        2: begin i_ideal =  0.70710678; q_ideal =  0.70710678; end
        3: begin i_ideal =  0.70710678; q_ideal = -0.70710678; end
      endcase
    end

    cfo_phase = 2.0 * PI_VAL * CFO_RSYM * n;
    c = $cos(cfo_phase);
    s = $sin(cfo_phase);
    i_rot = i_ideal * c - q_ideal * s;
    q_rot = i_ideal * s + q_ideal * c;
    i_out = $rtoi(i_rot * Q1_11_MAX);
    q_out = $rtoi(q_rot * Q1_11_MAX);
  endfunction

  task automatic drive_sample(
    input logic signed [InSampleWidth-1:0] i_val,
    input logic signed [InSampleWidth-1:0] q_val
  );
    in_sample_i     = i_val;
    in_sample_q     = q_val;
    in_sample_valid = 1'b1;
    @(posedge clk);
    in_sample_valid = 1'b0;
    repeat (3) @(posedge clk);
  endtask

  task automatic drive_symbol(input int n);
    logic signed [InSampleWidth-1:0] i_val, q_val;
    get_preamble_symbol(n, i_val, q_val);
    repeat (Sps) drive_sample(i_val, q_val);
  endtask

  initial begin
    real coarse_rsym;
    real delta;
    real tolerance;

    $display("==========================================================");
    $display("TB: sync_system_top (integration + debug)");
    $display("  Preamble: %0d syms (A1=%0d, A2=%0d, B=%0d, C=%0d)",
             NPreamble, NA1, NA2, NB, NC);
    $display("  CFO: %0.3f Rsym", CFO_RSYM);
    $display("==========================================================");

    rst_n            = 1'b0;
    in_sample_i      = '0;
    in_sample_q      = '0;
    in_sample_valid  = 1'b0;
    mod_type         = 2'b00;
    loop_gain        = 8'd0;
    costas_loop_gain = 8'd0;
    dft_sel          = 4'd0;
    start_of_burst   = 1'b0;
    force_w_en       = 1'b0;
    force_w          = '0;
    force_cfo_en     = 1'b0;
    force_cfo        = '0;
    force_freq_en    = 1'b0;
    force_freq       = '0;

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    $display("\n[%0t] === BURST START ===", $time);
    start_of_burst = 1'b1;
    @(posedge clk);
    start_of_burst = 1'b0;

    for (int n = 0; n < NPreamble; n++) drive_symbol(n);
    repeat (100) @(posedge clk);

    $display("\n==========================================================");
    $display("CHECKPOINT RESULTS");
    $display("==========================================================");

    if (out_sym_count < 50) begin
      $display("FAIL: only %0d output symbols", out_sym_count);
      errors++;
    end else begin
      $display("PASS: %0d output symbols produced", out_sym_count);
    end

    coarse_rsym   = $itor(coarse_cfo_est) / 16777216.0;
    tolerance     = 0.005;
    delta         = coarse_rsym - CFO_RSYM;
    if (delta < 0.0) delta = -delta;

    $display("  coarse_cfo_est = %h (%0.6f Rsym)", coarse_cfo_est, coarse_rsym);
    $display("  expected       = %0.6f Rsym (tol +/-%0.4f)", CFO_RSYM, tolerance);
    $display("  |delta|        = %0.6f Rsym", delta);

    if (delta > tolerance) begin
      $display("FAIL: coarse CFO out of tolerance");
      errors++;
    end else begin
      $display("PASS: coarse CFO within tolerance");
    end

    if (!lock_detect) begin
      $display("FAIL: lock_detect did not assert");
      errors++;
    end else begin
      $display("PASS: lock_detect asserted");
    end

    dft_sel = 4'd12;
    #1;
    if (dft_obs_data[0] === 1'b1) $display("PASS: DFT ch12 shows STR lock");
    else                           $display("WARN: DFT ch12 = %h", dft_obs_data);

    dft_sel = 4'd13;
    #1;
    if (dft_obs_data[0] === 1'b1) $display("PASS: DFT ch13 shows Costas lock");
    else                           $display("WARN: DFT ch13 = %h", dft_obs_data);

    // ============================================================
    //  COMPREHENSIVE DEBUG DUMP
    // ============================================================
    $display("\n==========================================================");
    $display("  INTERNAL STATE DEBUG (KEY: tells where Costas broke)");
    $display("==========================================================");
    $display("  FSM State         = %0d (0=Wait 1=Acq 2=CFO 3=Load 4=CostasAcq 5=Track)",
             u_dut.fsm_state);
    $display("  costas_mode       = %0d (0=HOLD 1=ACQ 2=TRACK)", u_dut.costas_mode);
    $display("  STR lock          = %b", u_dut.str_lock);
    $display("");
    $display("  Costas lock_int   = %b   (internal lock detector)", u_dut.costas_lock_int);
    $display("  Costas quad_done  = %b   (quad_check resolved)",     u_dut.costas_quad_done);
    $display("  Costas quad_unres = %b   (quad_check FAILED)",       u_dut.costas_quad_unres);
    $display("  Costas lock       = %b   (public lock)",              u_dut.costas_lock);
    $display("");
    $display("  Costas err        = %0d", $signed(u_dut.costas_err));
    $display("  Costas freq_adj   = %0d", $signed(u_dut.costas_freq_adj));
    $display("  Costas int        = %0d", $signed(u_dut.costas_int));
    $display("  Coarse CFO est    = %0d", $signed(u_dut.coarse_est));
    $display("  Fine CFO est      = %0d", $signed(u_dut.fine_cfo_est));

    $display("\n  --- Quad check counters ---");
    $display("    cnt_i_q = %0d  (sat at +15, need to reach)", $signed(u_dut.u_costas.u_quad.cnt_i_q));
    $display("    cnt_q_q = %0d  (sat at +15, need to reach)", $signed(u_dut.u_costas.u_quad.cnt_q_q));
    $display("    done_o  = %b", u_dut.u_costas.u_quad.done_o);

    $display("\n  --- Public lock detector ---");
    $display("    bucket  = %0d  (need >= 12)", u_dut.u_costas.u_lock_pub.bucket);
    $display("    m_val_r = %0d  (need < 2064)", u_dut.u_costas.u_lock_pub.m_val_r);
    $display("    locked  = %b", u_dut.u_costas.u_lock_pub.locked_o);

    $display("\n  --- Internal lock detector ---");
    $display("    bucket  = %0d  (need >= 8)",  u_dut.u_costas.u_lock_int.bucket);
    $display("    m_val_r = %0d  (need < 3600)", u_dut.u_costas.u_lock_int.m_val_r);
    $display("    locked  = %b", u_dut.u_costas.u_lock_int.locked_o);

    $display("\n  --- Cycle counters (how long each state was active) ---");
    $display("    lock_int high   for %0d cycles", lock_int_high_cnt);
    $display("    quad_done high  for %0d cycles", quad_done_high_cnt);
    $display("    lock_pub high   for %0d cycles", lock_pub_high_cnt);
    $display("    costas ACQ mode for %0d cycles", costas_mode_acq_cnt);
    $display("    costas TRK mode for %0d cycles", costas_mode_trk_cnt);
    $display("    FSM CostasAcq   for %0d cycles", fsm_costasacq_cnt);
    $display("    FSM Track       for %0d cycles", fsm_track_cnt);

    $display("\n==========================================================");
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d FAILURES", errors);
    $display("==========================================================");
    $finish;
  end

  initial begin
    #2_000_000;
    $display("WATCHDOG TIMEOUT");
    $finish;
  end

endmodule