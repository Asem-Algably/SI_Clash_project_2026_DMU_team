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
  parameter int unsigned InSampleWidth = 12,   // Q1.11
  parameter int unsigned OutSymWidth   = 16,   // Q1.15
  parameter int unsigned CoarseWidth   = 24,   // 2^24 = 1 turn/symbol
  parameter int unsigned PhaseWidth    = 32,   // 2^32 = 1 turn (R.120)
  parameter int unsigned MuWidth       = 10,   // Fractional delay (R.110)
  parameter int unsigned DftSelWidth   = 4,    // 16 observation channels

  // ---------------------------------------------------------------------
  // Preamble timing in symbols (from get_hw_config.m)
  // ---------------------------------------------------------------------
  parameter int unsigned NA1       = 70,    // STR acquire
  parameter int unsigned NA2       = 40,    // Coarse CFO estimation
  parameter int unsigned NPreamble = 190,   // Total preamble (strict)

  // ---------------------------------------------------------------------
  // Modulation and Costas mode encoding (TBD with organizers; the values
  // below match the internal constants of costas_top.sv)
  // ---------------------------------------------------------------------
  parameter logic [1:0] ModQpsk     = 2'b00,
  parameter logic [1:0] ModQam16    = 2'b01,
  parameter logic [1:0] CostasHold  = 2'b00,
  parameter logic [1:0] CostasAcq   = 2'b01,
  parameter logic [1:0] CostasTrack = 2'b10,

  // ---------------------------------------------------------------------
  // Error alignment latency in clock cycles (TBD by simulation)
  // ---------------------------------------------------------------------
  parameter int unsigned TedErrAlign   = 2,
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

  // Configuration (R.107, R.123, R.124 encodings TBD with organizers)
  input  logic [1:0]                      mod_type,
  input  logic [7:0]                      loop_gain,          // currently unused
  input  logic [7:0]                      costas_loop_gain,   // currently unused
  input  logic [DftSelWidth-1:0]          dft_sel,

  // Burst start (1-cycle pulse; e.g. in_sample_valid rising edge)
  input  logic                            start_of_burst,

  // DFT force overrides (drive from AXI register file, tie to 0 if unused)
  input  logic                            force_w_en,
  input  logic [15:0]                     force_w,
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
  output logic                            flush_active,
  output logic [7:0]                      valid_during_flush,
  output logic [31:0]                     dft_obs_data
);

  // -------------------------------------------------------------------------
  // Internal signals
  // -------------------------------------------------------------------------
  logic rst_n_sync;

  // STR (str_top.sv) outputs
  logic               str_valid;
  logic signed [15:0] str_sym_i, str_sym_q;
  logic               str_lock;
  logic signed [31:0] ted_err;
  logic               ted_err_valid;
  logic [MuWidth-1:0] str_mu;
  logic [15:0]        str_w;

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
  logic [1:0]                    costas_mode;
  logic                          preamble_end;
  logic                          slicer_qpsk;
  logic                          costas_freq_valid;
  logic signed [PhaseWidth-1:0]  costas_freq_adj;
  logic signed [PhaseWidth-1:0]  costas_int;
  logic                          costas_phase_valid;
  logic [PhaseWidth-1:0]         costas_phase_adj;
  logic                          costas_quad_unres;
  logic                          costas_lock;
  logic signed [15:0]            costas_err;
  logic                          costas_err_valid;
  logic                          costas_lock_int;
  logic                          costas_quad_done;

  // Burst FSM
  logic [2:0] fsm_state;

  // Aligned errors
  logic signed [31:0] ted_err_aligned;
  logic               ted_err_aligned_valid;
  logic signed [15:0] costas_err_aligned;
  logic               costas_err_aligned_valid;

  // DFT observation bus (16 channels)
  logic [15:0][31:0] dft_obs_bus;

  // -------------------------------------------------------------------------
  // Reset synchronizer & Soft-Reset generation
  // -------------------------------------------------------------------------
  logic flush_rst;
  logic rst_n_eff;

  reset_sync u_reset_sync (
    .clk_i (clk),
    .rst_ni(rst_n),
    .rst_no(rst_n_sync)
  );

  assign rst_n_eff = rst_n_sync & ~flush_rst;

  // Repeat pad sample buffer feeding STR during FLUSH
  logic signed [InSampleWidth-1:0] last_in_i, last_in_q;
  logic signed [InSampleWidth-1:0] str_in_i, str_in_q;

  always_ff @(posedge clk or negedge rst_n_sync) begin
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
  str_top u_str (
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
  // Coarse CFO Estimator (lag-4 correlation + CORDIC)
  // -------------------------------------------------------------------------
  coarse_cfo_core #(
    .DataWidth(16),
    .Lag      (4),
    .WinLen   (32),
    .AccWidth (40)
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
  derotator #(
    .Width       (PhaseWidth),
    .Phase_Bits  (12),
    .DataWidth   (16),
    .Frac        (15),
    .Coarse_W    (CoarseWidth),
    .Coarse_Shift(PhaseWidth - CoarseWidth)
  ) u_derotator (
    .clk_i            (clk),
    .rst_ni           (rst_n_eff),
    .s_axis_valid_i   (str_valid),
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
  costas_top u_costas (
    .clk_i            (clk),
    .rst_ni           (rst_n_eff),
    .s_axis_valid_i   (derot_valid),
    .s_axis_i_sym_i   (derot_sym_i),
    .s_axis_q_sym_i   (derot_sym_q),
    .mod_type_i       (mod_type),
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
    .NA1      (NA1),
    .NA2      (NA2),
    .NPreamble(NPreamble),
    .CostasHold (CostasHold),
    .CostasAcq  (CostasAcq),
    .CostasTrack(CostasTrack)
  ) u_burst_ctrl (
    .clk_i               (clk),
    .rst_ni              (rst_n_sync),
    .start_of_burst_i    (start_of_burst),
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
  assign slicer_qpsk = (fsm_state != 3'd5);  // 5 = StTrack

  // -------------------------------------------------------------------------
  // Error alignment
  // -------------------------------------------------------------------------
  err_align #(
    .StrDelay   (TedErrAlign),
    .CostasDelay(CostasErrAlign)
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
  always_comb begin
    dft_obs_bus[0]  = ted_err_aligned;
    dft_obs_bus[1]  = {{(32-MuWidth){1'b0}}, str_mu};
    dft_obs_bus[2]  = {16'b0, str_w};
    dft_obs_bus[3]  = {{16{str_sym_i[15]}}, str_sym_i};
    dft_obs_bus[4]  = {{(32-CoarseWidth){coarse_est[CoarseWidth-1]}}, coarse_est};
    dft_obs_bus[5]  = {{16{costas_err_aligned[15]}}, costas_err_aligned};
    dft_obs_bus[6]  = nco_freq_word;
    dft_obs_bus[7]  = nco_phase;
    dft_obs_bus[8]  = {{16{derot_sym_i[15]}}, derot_sym_i};
    dft_obs_bus[9]  = costas_int;
    dft_obs_bus[10] = costas_phase_adj;
    dft_obs_bus[11] = costas_freq_adj;
    dft_obs_bus[12] = {31'b0, str_lock};
    dft_obs_bus[13] = {31'b0, costas_lock};
    dft_obs_bus[14] = {29'b0, fsm_state};
    dft_obs_bus[15] = {31'b0, str_valid};
  end

  dft_mux #(
    .NumChannels(16),
    .DataWidth  (32),
    .DftSelWidth(DftSelWidth)
  ) u_dft_mux (
    .dft_sel_i     (dft_sel),
    .obs_data_i    (dft_obs_bus),
    .dft_obs_data_o(dft_obs_data)
  );

  // -------------------------------------------------------------------------
  // Top-level outputs
  // -------------------------------------------------------------------------
  assign out_sym_i     = derot_sym_i;
  assign out_sym_q     = derot_sym_q;
  assign out_sym_valid = derot_valid;

  assign coarse_cfo_est = coarse_est;

  // fine_cfo_est = coarse word (scaled to 2^32 = 1 turn) + loop integrator.
  // The coarse word is 24-bit (2^24 = 1 turn); append 8 zeros to convert to
  // 32-bit NCO units. $signed() reinterprets the concatenation as signed,
  // preserving the coarse_est sign bit at position 31.
  assign fine_cfo_est = $signed({coarse_est, {(PhaseWidth-CoarseWidth){1'b0}}})
                        + costas_int;

  // lock_detect = STR lock AND public Costas lock (wrapper.md Section 3)
  assign lock_detect = str_lock & costas_lock;

endmodule