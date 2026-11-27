////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         system_top
// Date:           14-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

module sync_system_top #(
  // ---------------------------------------------------------------------
  // Widths (match spec R.104, R.105, R.120)
  // ---------------------------------------------------------------------
  parameter int unsigned InSampleWidth         = 12,   // Q1.11
  parameter int unsigned InSampleIntWidth      = 1,
  parameter int unsigned OutSymWidth           = 16,   // Q1.15
  parameter int unsigned OutSymIntWidth        = 1,
  parameter int unsigned CoarseWidth           = 24,   // 2^24 = 1 turn/symbol
  parameter int unsigned PhaseWidth            = 32,   // 2^32 = 1 turn (R.120)
  parameter int unsigned MuWidth               = 10,   // Fractional delay (R.110)
  parameter int unsigned DftSelWidth           = 4,    // 16 observation channels
  parameter int unsigned GainWidth             = 8,
  parameter int unsigned ModWidth              = 2,
  parameter int unsigned ModeWidth             = 2,
  parameter int unsigned StateWidth            = 3,
  parameter int unsigned TedErrWidth           = 32,
  parameter int unsigned ForceWWidth           = 16,
  parameter int unsigned CoarseLag             = 4,
  parameter int unsigned CoarseWinLen          = 32,
  parameter int unsigned CoarseAccWidth        = 40,
  parameter int unsigned CordicIter            = 16,
  parameter int unsigned DerotPhaseBits        = 12,
  parameter int unsigned ModPipeDepth          = 10,
  parameter int unsigned DftDataWidth          = 32,
  parameter int unsigned NumDftChannels        = 16,
  parameter int unsigned IdleTimeout           = 14,
  parameter int unsigned FlushClocks           = 16,
  parameter int unsigned ValidDuringFlushWidth = 8,

  // ---------------------------------------------------------------------
  // Preamble timing in symbols (from get_hw_config.m)
  // ---------------------------------------------------------------------
  parameter int unsigned NA1       = 70,    // STR acquire
  parameter int unsigned NA2       = 40,    // Coarse CFO estimation
  parameter int unsigned NPreamble = 190,   // Total preamble (strict)

  // ---------------------------------------------------------------------
  // Modulation and Costas mode encoding (propagated to costas_top & burst_ctrl)
  // ---------------------------------------------------------------------
  parameter logic [ModWidth-1:0]  ModQpsk     = 2'b00,
  parameter logic [ModWidth-1:0]  ModQam16    = 2'b01,
  parameter logic [ModeWidth-1:0] CostasHold  = 2'b00,
  parameter logic [ModeWidth-1:0] CostasAcq   = 2'b01,
  parameter logic [ModeWidth-1:0] CostasTrack = 2'b10,

  // ---------------------------------------------------------------------
  // Error alignment latency in clock cycles
  // ---------------------------------------------------------------------
  parameter int unsigned TedErrAlign    = 2,
  parameter int unsigned CostasErrAlign = 0
) (
  // ---------------------------------------------------------------------
  // Spec ports (Real-Time All-Digital, Section 2).
  // The I/Q suffixes on in_sample_i/_q and out_sym_i/_q denote I/Q
  // components, not input/output. This is the documented exception to the
  // lowRISC _i/_o suffix rule.
  // ---------------------------------------------------------------------
  input  logic                            clk,
  input  logic                            rst_n,

  // Input samples (R.104: 12-bit signed Q1.11, 4 samples/symbol)
  input  logic signed [InSampleWidth-1:0] in_sample_i,
  input  logic signed [InSampleWidth-1:0] in_sample_q,
  input  logic                            in_sample_valid,

  // Configuration (R.107, R.123, R.124)
  input  logic [ModWidth-1:0]             mod_type,
  input  logic [GainWidth-1:0]            loop_gain,          // currently unused
  input  logic [GainWidth-1:0]            costas_loop_gain,   // currently unused
  input  logic [DftSelWidth-1:0]          dft_sel,

  // DFT force overrides (drive from AXI register file, tie to 0 if unused)
  input  logic                            force_w_en,
  input  logic [ForceWWidth-1:0]          force_w,
  input  logic                            force_cfo_en,
  input  logic signed [CoarseWidth-1:0]   force_cfo,
  input  logic                            force_freq_en,
  input  logic [PhaseWidth-1:0]           force_freq,

  // Outputs (R.105, R.106)
  output logic signed [OutSymWidth-1:0]   out_sym_i,
  output logic signed [OutSymWidth-1:0]   out_sym_q,
  output logic                            out_sym_valid,
  output logic signed [CoarseWidth-1:0]   coarse_cfo_est,
  output logic signed [PhaseWidth-1:0]    fine_cfo_est,
  output logic                            lock_detect,
  output logic [DftDataWidth-1:0]         dft_obs_data
);

  localparam int unsigned InSampleFracWidth = InSampleWidth - InSampleIntWidth;
  localparam int unsigned OutSymFracWidth   = OutSymWidth - OutSymIntWidth;
  localparam int unsigned MultOutWidth      = 2 * OutSymWidth + 1;
  localparam logic [StateWidth-1:0] StCostasAcqVal = StateWidth'(4);
  localparam logic [StateWidth-1:0] StTrackVal     = StateWidth'(5);

  // -------------------------------------------------------------------------
  // Internal signals
  // -------------------------------------------------------------------------
  logic rst_n_sync;

  // STR (str_top.sv) outputs
  logic                            str_valid;
  logic signed [OutSymWidth-1:0]   str_sym_i, str_sym_q;
  logic                            str_lock;
  logic signed [TedErrWidth-1:0]   ted_err;
  logic                            ted_err_valid;
  logic [MuWidth-1:0]              str_mu;
  logic [ForceWWidth-1:0]          str_w;

  // Coarse CFO interface
  logic                          coarse_start;
  logic                          coarse_valid;
  logic signed [CoarseWidth-1:0] coarse_est;

  // Derotator interface
  logic                          derot_valid;
  logic signed [OutSymWidth-1:0] derot_sym_i, derot_sym_q;
  logic [PhaseWidth-1:0]         nco_phase;
  logic [PhaseWidth-1:0]         nco_freq_word;

  // Costas interface
  logic [ModeWidth-1:0]          costas_mode;
  logic                          preamble_end;
  logic                          slicer_qpsk;
  logic                          costas_freq_valid;
  logic signed [PhaseWidth-1:0]  costas_freq_adj;
  logic signed [PhaseWidth-1:0]  costas_int;
  logic                          costas_phase_valid;
  logic [PhaseWidth-1:0]         costas_phase_adj;
  logic                          costas_quad_unres;
  logic                          costas_lock;
  logic signed [OutSymWidth-1:0] costas_err;
  logic                          costas_err_valid;
  logic                          costas_lock_int;
  logic                          costas_quad_done;

  // Burst FSM & flush status (internal observation nodes)
  logic [StateWidth-1:0]            fsm_state;
  logic                             flush_active;
  logic [ValidDuringFlushWidth-1:0] valid_during_flush;

  // Aligned errors
  logic signed [TedErrWidth-1:0] ted_err_aligned;
  logic                          ted_err_aligned_valid;
  logic signed [OutSymWidth-1:0] costas_err_aligned;
  logic                          costas_err_aligned_valid;

  // DFT observation bus
  logic [NumDftChannels-1:0][DftDataWidth-1:0] dft_obs_bus;

  // -------------------------------------------------------------------------
  // Synchronous Reset & Soft-Reset generation
  // -------------------------------------------------------------------------
  logic flush_rst;
  logic rst_n_eff;

  assign rst_n_sync = rst_n;
  assign rst_n_eff  = rst_n_sync & ~flush_rst;

  // Repeat pad sample buffer feeding STR during FLUSH
  logic signed [InSampleWidth-1:0] last_in_i, last_in_q;
  logic signed [InSampleWidth-1:0] str_in_i, str_in_q;

  always_ff @(posedge clk) begin
    if (!rst_n_sync) begin
      last_in_i <= '0;
      last_in_q <= '0;
    end else if (in_sample_valid) begin
      last_in_i <= in_sample_i;
      last_in_q <= in_sample_q;
    end
  end

  assign str_in_i = flush_active ? last_in_i : in_sample_i;
  assign str_in_q = flush_active ? last_in_q : in_sample_q;

  // -------------------------------------------------------------------------
  // STR: Symbol Timing Recovery (str_top.sv)
  // The provided STR module is named "str_top" in str_top.sv. The ports are declared
  // unsigned in that file, but the bit pattern is passed through unchanged;
  // downstream signed consumers reinterpret the bits correctly.
  // -------------------------------------------------------------------------
  str_top #(
    .InSampleIntWidth (InSampleIntWidth),
    .InSampleFracWidth(InSampleFracWidth),
    .OutSymIntWidth   (OutSymIntWidth),
    .OutSymFracWidth  (OutSymFracWidth),
    .GainWidth        (GainWidth),
    .TedErrWidth      (TedErrWidth),
    .MuWidth          (MuWidth),
    .ForceWWidth      (ForceWWidth)
  ) u_str (
    .clk_i            (clk),
    .rst_ni           (rst_n_eff),
    .s_axis_valid_i   (in_sample_valid),
    .flush_active_i   (flush_active),
    .s_axis_i_sample_i(str_in_i),
    .s_axis_q_sample_i(str_in_q),
    .loop_gain_i      (loop_gain),
    .m_axis_valid_o   (str_valid),
    .m_axis_i_sym_o   (str_sym_i),
    .m_axis_q_sym_o   (str_sym_q),
    .lock_o           (str_lock),
    .ted_err_valid_o  (ted_err_valid),
    .ted_err_o        (ted_err),
    .mu_o             (str_mu),
    .w_o              (str_w),
    .force_w_en_i     (force_w_en),
    .force_w_i        (force_w)
  );

  // -------------------------------------------------------------------------
  // Coarse CFO Estimator (lag-D correlation + CORDIC)
  // -------------------------------------------------------------------------
  coarse_cfo_core #(
    .DataWidth (OutSymWidth),
    .Lag       (CoarseLag),
    .WinLen    (CoarseWinLen),
    .AccWidth  (CoarseAccWidth),
    .OutWidth  (CoarseWidth),
    .MultWidth (MultOutWidth),
    .CordicIter(CordicIter)
  ) u_coarse_cfo (
    .clk_i          (clk),
    .rst_ni         (rst_n_eff),
    .start_i        (coarse_start),
    .s_axis_valid_i (str_valid),
    .s_axis_i_sym_i (str_sym_i),
    .s_axis_q_sym_i (str_sym_q),
    .m_axis_valid_o (coarse_valid),
    .m_axis_cfo_o   (coarse_est),
    .force_cfo_en_i (force_cfo_en),
    .force_cfo_i    (force_cfo)
  );

  // -------------------------------------------------------------------------
  // Derotator (NCO + quarter-wave ROM + quadrant rotator + complex mult)
  // -------------------------------------------------------------------------
  // Gated derotator valid input (active during CostasAcq and Track)
  logic str_valid_gated;
  assign str_valid_gated = str_valid & (fsm_state >= StCostasAcqVal);

  derotator #(
    .Width       (PhaseWidth),
    .Phase_Bits  (DerotPhaseBits),
    .DataWidth   (OutSymWidth),
    .Frac        (OutSymFracWidth),
    .Coarse_W    (CoarseWidth),
    .Coarse_Shift(PhaseWidth - CoarseWidth)
  ) u_derotator (
    .clk_i            (clk),
    .rst_ni           (rst_n_eff),
    .s_axis_valid_i   (str_valid_gated),
    .s_axis_i_sym_i   (str_sym_i),
    .s_axis_q_sym_i   (str_sym_q),
    .coarse_valid_i   (coarse_valid),
    .coarse_word_i    (coarse_est),
    .freq_adj_valid_i (costas_freq_valid),
    .freq_adj_i       (costas_freq_adj),
    .force_freq_en_i  (force_freq_en),
    .force_freq_i     (force_freq),
    .phase_adj_valid_i(costas_phase_valid),
    .phase_adj_i      (costas_phase_adj),
    .m_axis_valid_o   (derot_valid),
    .m_axis_i_sym_o   (derot_sym_i),
    .m_axis_q_sym_o   (derot_sym_q),
    .phase_o          (nco_phase),
    .freq_word_o      (nco_freq_word)
  );

  // -------------------------------------------------------------------------
  // Costas Loop (slicer + phase error + PI filter + lock detector + quad check)
  // -------------------------------------------------------------------------
  // Pipeline delay for mod_type matching STR + Derotator latency
  logic [ModWidth-1:0] mod_type_pipe [0:ModPipeDepth-1];
  always_ff @(posedge clk) begin
    if (!rst_n_sync) begin
      for (int i = 0; i < ModPipeDepth; i++) mod_type_pipe[i] <= ModQpsk;
    end else begin
      mod_type_pipe[0] <= mod_type;
      for (int i = 1; i < ModPipeDepth; i++) mod_type_pipe[i] <= mod_type_pipe[i-1];
    end
  end

  costas_top #(
    .Data_Width    (OutSymWidth),
    .Error_Width   (OutSymWidth),
    .Phase_Width   (PhaseWidth),
    .Data_Frac_Bits(OutSymFracWidth),
    .ModWidth      (ModWidth),
    .ModQpsk       (ModQpsk),
    .ModQam16      (ModQam16),
    .ModeWidth     (ModeWidth),
    .ModeHold      (CostasHold),
    .ModeAcq       (CostasAcq),
    .GainPortWidth (GainWidth)
  ) u_costas (
    .clk_i            (clk),
    .rst_ni           (rst_n_eff),
    .s_axis_valid_i   (derot_valid),
    .s_axis_i_sym_i   (derot_sym_i),
    .s_axis_q_sym_i   (derot_sym_q),
    .mod_type_i       (mod_type_pipe[ModPipeDepth-1]),
    .costas_gain_i    (costas_loop_gain),
    .mode_i           (costas_mode),
    .slicer_qpsk_i    (slicer_qpsk),
    .preamble_end_i   (preamble_end),
    .freq_adj_valid_o (costas_freq_valid),
    .freq_adj_o       (costas_freq_adj),
    .int_o            (costas_int),
    .phase_adj_valid_o(costas_phase_valid),
    .phase_adj_o      (costas_phase_adj),
    .quad_unresolved_o(costas_quad_unres),
    .lock_o           (costas_lock),
    .dbg_e_o          (costas_err),
    .dbg_e_valid_o    (costas_err_valid),
    .dbg_lock_int_o   (costas_lock_int),
    .dbg_quad_done_o  (costas_quad_done)
  );

  // -------------------------------------------------------------------------
  // Burst FSM & Watchdog Controller
  // -------------------------------------------------------------------------
  burst_ctrl #(
    .NA1                  (NA1),
    .NA2                  (NA2),
    .NPreamble            (NPreamble),
    .IDLE_TIMEOUT         (IdleTimeout),
    .FLUSH_CLOCKS         (FlushClocks),
    .StateWidth           (StateWidth),
    .ModeWidth            (ModeWidth),
    .ValidDuringFlushWidth(ValidDuringFlushWidth),
    .CostasHold           (CostasHold),
    .CostasAcq            (CostasAcq),
    .CostasTrack          (CostasTrack)
  ) u_burst_ctrl (
    .clk_i               (clk),
    .rst_ni              (rst_n_sync),
    .in_sample_valid_i   (in_sample_valid),
    .str_lock_i          (str_lock),
    .coarse_valid_i      (coarse_valid),
    .sym_strobe_i        (str_valid),
    .coarse_start_o      (coarse_start),
    .costas_mode_o       (costas_mode),
    .preamble_end_o      (preamble_end),
    .state_o             (fsm_state),
    .flush_active_o      (flush_active),
    .flush_rst_o         (flush_rst),
    .valid_during_flush_o(valid_during_flush)
  );

  // -------------------------------------------------------------------------
  // Slicer force-QPSK control: during acquisition the preamble is QPSK-like
  // for both modulations, so force the slicer to QPSK until Track.
  // -------------------------------------------------------------------------
  assign slicer_qpsk = (fsm_state != StTrackVal);

  // -------------------------------------------------------------------------
  // Error alignment
  // -------------------------------------------------------------------------
  err_align #(
    .StrDelay   (TedErrAlign),
    .CostasDelay(CostasErrAlign),
    .TedWidth   (TedErrWidth),
    .CostasWidth(OutSymWidth)
  ) u_err_align (
    .clk_i            (clk),
    .rst_ni           (rst_n_sync),
    .ted_err_i        (ted_err),
    .ted_err_valid_i  (ted_err_valid),
    .costas_err_i     (costas_err),
    .costas_err_valid_i(costas_err_valid),
    .ted_err_o        (ted_err_aligned),
    .ted_err_valid_o  (ted_err_aligned_valid),
    .costas_err_o     (costas_err_aligned),
    .costas_err_valid_o(costas_err_aligned_valid)
  );

  // -------------------------------------------------------------------------
  // DFT observation bus
  // -------------------------------------------------------------------------
  logic [15:0][DftDataWidth-1:0] dft_all_ch;
  always_comb begin
    dft_all_ch[0]  = DftDataWidth'($signed(ted_err_aligned));
    dft_all_ch[1]  = DftDataWidth'(str_mu);
    dft_all_ch[2]  = DftDataWidth'(str_w);
    dft_all_ch[3]  = DftDataWidth'($signed(str_sym_i));
    dft_all_ch[4]  = DftDataWidth'($signed(coarse_est));
    dft_all_ch[5]  = DftDataWidth'($signed(costas_err_aligned));
    dft_all_ch[6]  = DftDataWidth'(nco_freq_word);
    dft_all_ch[7]  = DftDataWidth'(nco_phase);
    dft_all_ch[8]  = DftDataWidth'($signed(derot_sym_i));
    dft_all_ch[9]  = DftDataWidth'(costas_int);
    dft_all_ch[10] = DftDataWidth'(costas_phase_adj);
    dft_all_ch[11] = DftDataWidth'(costas_freq_adj);
    dft_all_ch[12] = DftDataWidth'(str_lock);
    dft_all_ch[13] = DftDataWidth'(costas_lock);
    dft_all_ch[14] = DftDataWidth'(fsm_state);
    dft_all_ch[15] = DftDataWidth'(str_valid);
  end

  generate
    for (genvar ch = 0; ch < NumDftChannels; ch++) begin : gen_dft_ch
      assign dft_obs_bus[ch] = (ch < 16) ? dft_all_ch[ch] : {DftDataWidth{1'b0}};
    end
  endgenerate

  dft_mux #(
    .NumChannels(NumDftChannels),
    .DataWidth  (DftDataWidth),
    .DftSelWidth(DftSelWidth)
  ) u_dft_mux (
    .dft_sel_i     (dft_sel),
    .obs_data_i    (dft_obs_bus),
    .dft_obs_data_o(dft_obs_data)
  );

  // -------------------------------------------------------------------------
  // Top-level outputs: direct wire assignment from derotator registered outputs
  // -------------------------------------------------------------------------
  assign out_sym_valid = derot_valid;
  assign out_sym_i     = derot_sym_i;
  assign out_sym_q     = derot_sym_q;

  assign coarse_cfo_est = coarse_est;

  // fine_cfo_est = coarse word (scaled to PhaseWidth = 1 turn) + loop integrator
  assign fine_cfo_est = $signed({coarse_est, {(PhaseWidth-CoarseWidth){1'b0}}})
                        + costas_int;

  // lock_detect = STR lock AND public Costas lock
  assign lock_detect = str_lock & costas_lock;

endmodule