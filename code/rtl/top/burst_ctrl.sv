////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim (Updated with Hardware Valid & Watchdog Scheme)
// Design:         Burst_ctrl
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

// Burst acquisition & Watchdog FSM:
// Controls coarse CFO start trigger, Costas loop mode across 190-symbol preamble,
// and implements an always-on idle watchdog that triggers StFlush on >= 14 invalid clocks.
//
// 7-State Progression:
//   WaitBurst (0) -> Acquire (1) -> CoarseEst (2) -> Load (3) -> CostasAcq (4) -> Track (5) -> Flush (6)

module burst_ctrl #(
  // Preamble timing in symbols (from get_hw_config.m)
  parameter int unsigned NA1          = 70,
  parameter int unsigned NA2          = 40,
  parameter int unsigned NPreamble    = 190,
  parameter int unsigned IDLE_TIMEOUT = 14,  // Consecutive invalid clocks to trigger Flush
  parameter int unsigned FLUSH_CLOCKS = 15,  // Pipeline drain clocks F

  // Costas mode encoding (must match costas_top.sv)
  parameter logic [1:0]  CostasHold  = 2'b00,
  parameter logic [1:0]  CostasAcq   = 2'b01,
  parameter logic [1:0]  CostasTrack = 2'b10
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Control inputs
  input  logic        start_of_burst_i,   // 1-cycle pulse or in_sample_valid from burst detector
  input  logic        in_sample_valid_i,  // Real-time input sample valid (for watchdog)
  input  logic        str_lock_i,         // STR lock (from STR top)
  input  logic        coarse_valid_i,     // Coarse CFO estimate ready
  input  logic        sym_strobe_i,       // Symbol-rate strobe (STR valid)

  // Control outputs
  output logic        coarse_start_o,     // Level: coarse CFO window active
  output logic [1:0]  costas_mode_o,      // HOLD / ACQ / TRACK for Costas
  output logic        preamble_end_o,     // 1-cycle pulse: preamble complete
  output logic [2:0]  state_o,            // FSM state (for DFT)
  output logic        flush_active_o,     // 1 during FLUSH state
  output logic        flush_rst_o,        // 1-cycle soft reset pulse after FLUSH drain
  output logic [7:0]  valid_during_flush_o // Count of valid samples arriving during FLUSH
);

  // --------------------------------------------------------------------------
  // State encoding
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    StWaitBurst = 3'd0,
    StAcquire   = 3'd1,
    StCoarseEst = 3'd2,
    StLoad      = 3'd3,
    StCostasAcq = 3'd4,
    StTrack     = 3'd5,
    StFlush     = 3'd6
  } state_e;

  state_e      state_q, state_d;
  logic [31:0] sym_cnt_q, sym_cnt_d;
  logic [7:0]  idle_cnt_q, idle_cnt_d;
  logic [7:0]  flush_cnt_q, flush_cnt_d;
  logic [7:0]  valid_during_flush_q, valid_during_flush_d;
  logic        flush_rst_q, flush_rst_d;

  // --------------------------------------------------------------------------
  // Combinational next-state logic
  // --------------------------------------------------------------------------
  always_comb begin
    // Defaults
    state_d              = state_q;
    sym_cnt_d            = sym_cnt_q;
    idle_cnt_d           = idle_cnt_q;
    flush_cnt_d          = flush_cnt_q;
    valid_during_flush_d = valid_during_flush_q;
    flush_rst_d          = 1'b0;

    coarse_start_o       = 1'b0;
    costas_mode_o        = CostasHold;
    preamble_end_o       = 1'b0;

    unique case (state_q)
      // ----------------------------------------------------------------
      StWaitBurst: begin
        idle_cnt_d  = '0;
        flush_cnt_d = '0;
        if (start_of_burst_i || in_sample_valid_i) begin
          state_d   = StAcquire;
          sym_cnt_d = '0;
        end
      end

      // ----------------------------------------------------------------
      StAcquire: begin
        if (sym_strobe_i) begin
          sym_cnt_d = sym_cnt_q + 1'b1;
        end
        if (str_lock_i || (sym_cnt_q >= (NA1 - 1))) begin
          state_d = StCoarseEst;
        end
      end

      // ----------------------------------------------------------------
      StCoarseEst: begin
        coarse_start_o = 1'b1;
        if (sym_strobe_i) begin
          sym_cnt_d = sym_cnt_q + 1'b1;
        end
        if (coarse_valid_i || (sym_cnt_q >= (NA1 + NA2 - 1))) begin
          state_d = StLoad;
        end
      end

      // ----------------------------------------------------------------
      StLoad: begin
        if (sym_strobe_i) begin
          state_d   = StCostasAcq;
          sym_cnt_d = sym_cnt_q + 1'b1;
        end
      end

      // ----------------------------------------------------------------
      StCostasAcq: begin
        costas_mode_o = CostasAcq;
        if (sym_strobe_i) begin
          sym_cnt_d = sym_cnt_q + 1'b1;
        end

        if (sym_cnt_q >= (NPreamble - 35)) begin
          state_d        = StTrack;
          preamble_end_o = 1'b1;
        end
      end

      // ----------------------------------------------------------------
      StTrack: begin
        costas_mode_o = CostasTrack;
      end

      // ----------------------------------------------------------------
      StFlush: begin
        costas_mode_o = CostasHold;
        flush_cnt_d   = flush_cnt_q + 1'b1;
        if (in_sample_valid_i) begin
          valid_during_flush_d = valid_during_flush_q + 1'b1;
        end
        if (flush_cnt_q >= (FLUSH_CLOCKS - 1)) begin
          state_d     = StWaitBurst;
          flush_rst_d = 1'b1; // Soft reset pulse to re-arm all modules
          flush_cnt_d = '0;
          idle_cnt_d  = '0;
        end
      end

      default: begin
        state_d   = StWaitBurst;
        sym_cnt_d = '0;
      end
    endcase

    // Always-on Idle Watchdog: counts invalid clocks during active states
    if ((state_q >= StAcquire) && (state_q <= StTrack)) begin
      if (!in_sample_valid_i) begin
        idle_cnt_d = idle_cnt_q + 1'b1;
        if (idle_cnt_q >= (IDLE_TIMEOUT - 1)) begin
          state_d     = StFlush;
          flush_cnt_d = '0;
        end
      end else begin
        idle_cnt_d = '0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Sequential state register
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q              <= StWaitBurst;
      sym_cnt_q            <= '0;
      idle_cnt_q           <= '0;
      flush_cnt_q          <= '0;
      valid_during_flush_q <= '0;
      flush_rst_q          <= 1'b0;
    end else begin
      state_q              <= state_d;
      sym_cnt_q            <= sym_cnt_d;
      idle_cnt_q           <= idle_cnt_d;
      flush_cnt_q          <= flush_cnt_d;
      valid_during_flush_q <= valid_during_flush_d;
      flush_rst_q          <= flush_rst_d;
    end
  end

  // Outputs
  assign state_o              = state_q;
  assign flush_active_o       = (state_q == StFlush);
  assign flush_rst_o          = flush_rst_q;
  assign valid_during_flush_o = valid_during_flush_q;

endmodule
