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
  parameter int unsigned NA1                   = 70,
  parameter int unsigned NA2                   = 40,
  parameter int unsigned NPreamble             = 190,
  parameter int unsigned IDLE_TIMEOUT          = 14,  // Consecutive invalid clocks to trigger Flush
  parameter int unsigned FLUSH_CLOCKS          = 16,  // Pipeline drain clocks F

  // Parameterized bus/counter widths and pipeline latency
  parameter int unsigned StateWidth            = 3,
  parameter int unsigned ModeWidth             = 2,
  parameter int unsigned SymCntWidth           = 32,
  parameter int unsigned ValidDuringFlushWidth = 8,
  parameter int unsigned PreambleEndDelay      = 4,

  // Costas mode encoding (must match costas_top.sv)
  parameter logic [ModeWidth-1:0] CostasHold  = 2'b00,
  parameter logic [ModeWidth-1:0] CostasAcq   = 2'b01,
  parameter logic [ModeWidth-1:0] CostasTrack = 2'b10
) (
  input  logic                             clk_i,
  input  logic                             rst_ni,

  // Control inputs
  input  logic                             in_sample_valid_i,  // Real-time input sample valid (burst start + watchdog)
  input  logic                             str_lock_i,         // STR lock (from STR top)
  input  logic                             coarse_valid_i,     // Coarse CFO estimate ready
  input  logic                             sym_strobe_i,       // Symbol-rate strobe (STR valid)

  // Control outputs
  output logic                             coarse_start_o,      // Level: coarse CFO window active
  output logic [ModeWidth-1:0]             costas_mode_o,       // HOLD / ACQ / TRACK for Costas
  output logic                             preamble_end_o,      // 1-cycle pulse: preamble complete
  output logic [StateWidth-1:0]            state_o,             // FSM state (for DFT)
  output logic                             flush_active_o,      // 1 during FLUSH state
  output logic                             flush_rst_o,         // 1-cycle soft reset pulse after FLUSH drain
  output logic [ValidDuringFlushWidth-1:0] valid_during_flush_o // Count of valid samples arriving during FLUSH
);

  localparam int unsigned IdleCntWidth  = $clog2(IDLE_TIMEOUT + 1);
  localparam int unsigned FlushCntWidth = $clog2(FLUSH_CLOCKS + 1);

  // --------------------------------------------------------------------------
  // State encoding
  // --------------------------------------------------------------------------
  typedef enum logic [StateWidth-1:0] {
    StWaitBurst = StateWidth'(0),
    StAcquire   = StateWidth'(1),
    StCoarseEst = StateWidth'(2),
    StLoad      = StateWidth'(3),
    StCostasAcq = StateWidth'(4),
    StTrack     = StateWidth'(5),
    StFlush     = StateWidth'(6)
  } state_e;

  state_e                             state_q, state_d;
  logic [SymCntWidth-1:0]             sym_cnt_q, sym_cnt_d;
  logic [IdleCntWidth-1:0]            idle_cnt_q, idle_cnt_d;
  logic [FlushCntWidth-1:0]           flush_cnt_q, flush_cnt_d;
  logic [ValidDuringFlushWidth-1:0]   valid_during_flush_q, valid_during_flush_d;
  logic                               flush_rst_q, flush_rst_d;
  logic [PreambleEndDelay-1:0]        pe_pipe_q;
  logic                               preamble_end_raw;

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
    preamble_end_raw     = 1'b0;

    unique case (state_q)
      // ----------------------------------------------------------------
      StWaitBurst: begin
        idle_cnt_d  = '0;
        flush_cnt_d = '0;
        if (in_sample_valid_i) begin
          state_d   = StAcquire;
          sym_cnt_d = '0;
        end
      end

      // ----------------------------------------------------------------
      StAcquire: begin
        if (sym_strobe_i) begin
          sym_cnt_d = sym_cnt_q + 1'b1;
          if (sym_cnt_q + 1'b1 >= NA1) begin
            state_d        = StCoarseEst;
            coarse_start_o = 1'b1;
          end
        end
        if (str_lock_i) begin
          state_d        = StCoarseEst;
          coarse_start_o = 1'b1;
        end
      end

      // ----------------------------------------------------------------
      StCoarseEst: begin
        coarse_start_o = 1'b1;
        if (sym_strobe_i) begin
          sym_cnt_d = sym_cnt_q + 1'b1;
          if (sym_cnt_q + 1'b1 >= (NA1 + NA2)) begin
            state_d = StLoad;
          end
        end
        if (coarse_valid_i) begin
          if (sym_strobe_i) begin
            state_d = StCostasAcq;
          end else begin
            state_d = StLoad;
          end
        end
      end

      // ----------------------------------------------------------------
      StLoad: begin
        // Wait for next STR symbol strobe to align derotator start (wrapper.md)
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
          if (sym_cnt_q + 1'b1 >= NPreamble) begin
            state_d          = StTrack;
            preamble_end_raw = 1'b1;
          end
        end
      end

      // ----------------------------------------------------------------
      StTrack: begin
        costas_mode_o = CostasTrack;
        if (sym_strobe_i) begin
          sym_cnt_d = sym_cnt_q + 1'b1;
        end
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
  // Sequential state register (Synchronous Reset)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q              <= StWaitBurst;
      sym_cnt_q            <= '0;
      idle_cnt_q           <= '0;
      flush_cnt_q          <= '0;
      valid_during_flush_q <= '0;
      flush_rst_q          <= 1'b0;
      pe_pipe_q            <= '0;
    end else begin
      state_q              <= state_d;
      sym_cnt_q            <= sym_cnt_d;
      idle_cnt_q           <= idle_cnt_d;
      flush_cnt_q          <= flush_cnt_d;
      valid_during_flush_q <= valid_during_flush_d;
      flush_rst_q          <= flush_rst_d;
      pe_pipe_q            <= {pe_pipe_q[2:0], preamble_end_raw};
    end
  end

  // Outputs
  assign state_o              = state_q;
  assign flush_active_o       = (state_q == StFlush);
  assign flush_rst_o          = flush_rst_q;
  assign valid_during_flush_o = valid_during_flush_q;
  assign preamble_end_o       = pe_pipe_q[3];

endmodule
