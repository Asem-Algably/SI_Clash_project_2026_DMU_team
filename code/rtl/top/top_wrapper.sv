// ============================================================================
// File Name   : top_wrapper.sv
// Module Name : top_wrapper
// Project     : SI-CLASH Real-Time Digital Synchronizer
// Description : Top-Level Synchronizer Integration Wrapper.
//               Cascades:
//                 Input Samples -> STR (Clock-Enabled)
//                               -> Coarse CFO Estimator
//                               -> Derotator / NCO
//                               -> Costas Loop Subsystem
//                               -> Output Stage & Watchdog/Flush FSM
// ============================================================================

module top_wrapper #(
    parameter int DATA_IN_WIDTH    = 12,   // ADC sample width, signed Q1.11
    parameter int SYM_WIDTH        = 16,   // Internal symbol width, signed Q1.15
    parameter int COARSE_WIDTH     = 24,   // Coarse CFO width, signed Q-1.24
    parameter int PHASE_WIDTH      = 32,   // NCO phase width, Q0.32
    parameter int PREAMBLE_N_A     = 70,   // Phase A1 STR acquire budget
    parameter int PREAMBLE_TOTAL   = 190,  // Total preamble budget
    parameter int IDLE_TIMEOUT     = 14,   // Consecutive invalid clocks before FLUSH
    parameter int FLUSH_CLOCKS     = 16    // Pipeline drain duration F
)(
    input  logic                                clk_i,
    input  logic                                rst_ni,

    // Input Sample Stream (AXI-Stream Slave, Valid-Only)
    input  logic                                s_axis_valid_i,
    input  logic signed [DATA_IN_WIDTH-1:0]     s_axis_i_sample_i,
    input  logic signed [DATA_IN_WIDTH-1:0]     s_axis_q_sample_i,

    // Static / Control Configuration
    input  logic                                mod_type_i, // 0 = QPSK, 1 = 16-QAM

    // Synchronized Symbol Output Stream (AXI-Stream Master)
    output logic                                m_axis_valid_o,
    output logic signed [SYM_WIDTH-1:0]         m_axis_i_sym_o,
    output logic signed [SYM_WIDTH-1:0]         m_axis_q_sym_o,

    // Status & Diagnostics
    output logic                                lock_detect_o,
    output logic signed [COARSE_WIDTH-1:0]      coarse_cfo_est_o,
    output logic signed [PHASE_WIDTH-1:0]       fine_cfo_est_o,
    output logic [2:0]                          fsm_state_o,
    output logic                                flush_active_o,
    output logic [7:0]                          valid_during_flush_o
);

    // =========================================================================
    // 1. Reset Trees & Flush Sample Multiplexer
    // =========================================================================
    logic flush_active;
    logic flush_rst;
    logic rst_eff_n;

    // Soft reset asserted during flush reset pulse
    assign rst_eff_n = rst_ni & ~flush_rst;

    // Pad sample repeat buffer for pipeline drain during FLUSH
    logic signed [DATA_IN_WIDTH-1:0] last_i_sample_q;
    logic signed [DATA_IN_WIDTH-1:0] last_q_sample_q;
    logic signed [DATA_IN_WIDTH-1:0] str_i_sample;
    logic signed [DATA_IN_WIDTH-1:0] str_q_sample;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            last_i_sample_q <= '0;
            last_q_sample_q <= '0;
        end else if (s_axis_valid_i) begin
            last_i_sample_q <= s_axis_i_sample_i;
            last_q_sample_q <= s_axis_q_sample_i;
        end
    end

    assign str_i_sample = flush_active ? last_i_sample_q : s_axis_i_sample_i;
    assign str_q_sample = flush_active ? last_q_sample_q : s_axis_q_sample_i;

    // =========================================================================
    // 2. Symbol Timing Recovery (STR) Module
    // =========================================================================
    logic                        str_valid;
    logic signed [SYM_WIDTH-1:0] str_i_sym;
    logic signed [SYM_WIDTH-1:0] str_q_sym;
    logic                        str_lock;

    top u_str (
        .clk_i            (clk_i),
        .rst_ni           (rst_eff_n),
        .s_axis_valid_i   (s_axis_valid_i),
        .flush_active_i   (flush_active),
        .s_axis_i_sample_i(str_i_sample),
        .s_axis_q_sample_i(str_q_sample),
        .loop_gain_i      (8'd0),
        .m_axis_valid_o   (str_valid),
        .m_axis_i_sym_o   (str_i_sym),
        .m_axis_q_sym_o   (str_q_sym),
        .lock_o           (str_lock),
        .ted_err_valid_o  (),
        .ted_err_o        (),
        .mu_o             (),
        .w_o              (),
        .force_w_en_i     (1'b0),
        .force_w_i        (16'd0)
    );

    // =========================================================================
    // 3. Coarse CFO Estimator Subsystem
    // =========================================================================
    logic                           coarse_start;
    logic                           coarse_valid;
    logic signed [COARSE_WIDTH-1:0] coarse_word;
    logic signed [COARSE_WIDTH-1:0] coarse_word_held;

    coarse_cfo_core #(
        .DataWidth(SYM_WIDTH),
        .Lag      (4),
        .WinLen   (32)
    ) u_coarse_cfo (
        .clk_i          (clk_i),
        .rst_ni         (rst_eff_n),
        .start_i        (coarse_start),
        .s_axis_valid_i (str_valid),
        .s_axis_i_sym_i (str_i_sym),
        .s_axis_q_sym_i (str_q_sym),
        .m_axis_valid_o (coarse_valid),
        .m_axis_cfo_o   (coarse_word),
        .force_cfo_en_i (1'b0),
        .force_cfo_i    (24'd0)
    );

    always_ff @(posedge clk_i or negedge rst_eff_n) begin
        if (!rst_eff_n) begin
            coarse_word_held <= '0;
        end else if (coarse_valid) begin
            coarse_word_held <= coarse_word;
        end
    end

    assign coarse_cfo_est_o = coarse_word_held;

    // =========================================================================
    // 4. Derotator / Carrier NCO Subsystem
    // =========================================================================
    logic                          freq_adj_valid;
    logic signed [PHASE_WIDTH-1:0] freq_adj;
    logic                          phase_adj_valid;
    logic        [PHASE_WIDTH-1:0] phase_adj;
    logic                          derot_valid;
    logic signed [SYM_WIDTH-1:0]   derot_i_sym;
    logic signed [SYM_WIDTH-1:0]   derot_q_sym;
    logic        [PHASE_WIDTH-1:0] derot_phase;
    logic        [PHASE_WIDTH-1:0] derot_freq_word;

    derotator #(
        .Width      (PHASE_WIDTH),
        .Phase_Bits (12),
        .DataWidth  (SYM_WIDTH),
        .Coarse_W   (COARSE_WIDTH)
    ) u_derotator (
        .clk_i            (clk_i),
        .rst_ni           (rst_eff_n),
        .s_axis_valid_i   (str_valid),
        .s_axis_i_sym_i   (str_i_sym),
        .s_axis_q_sym_i   (str_q_sym),
        .coarse_valid_i   (coarse_valid),
        .coarse_word_i    (coarse_word),
        .freq_adj_valid_i (freq_adj_valid),
        .freq_adj_i       (freq_adj),
        .force_freq_en_i  (1'b0),
        .force_freq_i     (32'd0),
        .phase_adj_valid_i(phase_adj_valid),
        .phase_adj_i      (phase_adj),
        .m_axis_valid_o   (derot_valid),
        .m_axis_i_sym_o   (derot_i_sym),
        .m_axis_q_sym_o   (derot_q_sym),
        .phase_o          (derot_phase),
        .freq_word_o      (derot_freq_word)
    );

    // =========================================================================
    // 5. Costas Loop Subsystem (Fine CFO & Phase Tracking)
    // =========================================================================
    logic [1:0]                    costas_mode;
    logic                          slicer_qpsk;
    logic                          preamble_end;
    logic signed [PHASE_WIDTH-1:0] costas_int;
    logic                          costas_lock;
    logic                          quad_unresolved;

    costas_top #(
        .Data_Width (SYM_WIDTH),
        .Error_Width(16),
        .Gain_Width (24),
        .Phase_Width(PHASE_WIDTH)
    ) u_costas (
        .clk_i            (clk_i),
        .rst_ni           (rst_eff_n),
        .s_axis_valid_i   (derot_valid),
        .s_axis_i_sym_i   (derot_i_sym),
        .s_axis_q_sym_i   (derot_q_sym),
        .mod_type_i       ({1'b0, mod_type_i}),
        .costas_gain_i    (8'd0),
        .mode_i           (costas_mode),
        .slicer_qpsk_i    (slicer_qpsk),
        .preamble_end_i   (preamble_end),
        .freq_adj_valid_o (freq_adj_valid),
        .freq_adj_o       (freq_adj),
        .int_o            (costas_int),
        .phase_adj_valid_o(phase_adj_valid),
        .phase_adj_o      (phase_adj),
        .quad_unresolved_o(quad_unresolved),
        .lock_o           (costas_lock),
        .dbg_e_o          (),
        .dbg_e_valid_o    (),
        .dbg_lock_int_o   (),
        .dbg_quad_done_o  ()
    );

    // Fine CFO total estimate = coarse CFO + Costas loop integrator
    assign fine_cfo_est_o = ($signed({{8{coarse_word_held[COARSE_WIDTH-1]}}, coarse_word_held}) <<< 8) + costas_int;
    assign lock_detect_o  = str_lock & costas_lock;

    // =========================================================================
    // 6. Top Wrapper Burst FSM & Watchdog Controller
    // =========================================================================
    wrapper_fsm #(
        .PREAMBLE_N_A   (PREAMBLE_N_A),
        .PREAMBLE_TOTAL (PREAMBLE_TOTAL),
        .IDLE_TIMEOUT   (IDLE_TIMEOUT),
        .FLUSH_CLOCKS   (FLUSH_CLOCKS)
    ) u_wrapper_fsm (
        .clk_i               (clk_i),
        .rst_ni              (rst_ni),
        .in_sample_valid_i   (s_axis_valid_i),
        .str_valid_i         (str_valid),
        .str_lock_i          (str_lock),
        .coarse_valid_i      (coarse_valid),
        .costas_lock_i       (costas_lock),
        .coarse_start_o      (coarse_start),
        .costas_mode_o       (costas_mode),
        .slicer_qpsk_o       (slicer_qpsk),
        .preamble_end_o      (preamble_end),
        .fsm_state_o         (fsm_state_o),
        .flush_active_o      (flush_active),
        .flush_rst_o         (flush_rst),
        .sym_cnt_o           (),
        .valid_during_flush_o(valid_during_flush_o)
    );

    assign flush_active_o = flush_active;

    // =========================================================================
    // 7. 1-Cycle Output Register Stage
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_eff_n) begin
        if (!rst_eff_n) begin
            m_axis_valid_o <= 1'b0;
            m_axis_i_sym_o <= '0;
            m_axis_q_sym_o <= '0;
        end else begin
            m_axis_valid_o <= derot_valid;
            if (derot_valid) begin
                m_axis_i_sym_o <= derot_i_sym;
                m_axis_q_sym_o <= derot_q_sym;
            end
        end
    end

endmodule
