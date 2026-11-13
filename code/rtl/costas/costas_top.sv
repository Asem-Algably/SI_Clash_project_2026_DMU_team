// ============================================================================
// File Name   : costas_top.sv
// Module Name : costas_top
// Author      : Arwa Kantoush
// Description : Top-level Costas Loop Subsystem wrapper incorporating slicer,
//               phase detector, PI filter, dual lock detectors, and quad check.
//               Separate loop gains for ACQ (preamble) and TRACK (payload).
// ============================================================================
module costas_top #(
    parameter int Data_Width     = 16,
    parameter int Error_Width    = 16,
    parameter int Gain_Width     = 24,
    parameter int Phase_Width    = 32,
    parameter int Data_Frac_Bits = 15,
    parameter int Gain_Frac_Bits = 24,
    parameter logic signed [Phase_Width-1:0] Max_Pi_Output = 32'sh1EB8_51EB,

    parameter logic signed [Data_Width-1:0]  Qpsk_Level    = 16'sd16384,
    parameter logic signed [Data_Width-1:0]  Qam_Level     = 16'sd5461,

    // Loop gains - ACQ (preamble): Bn_Ts ~ 0.035
    parameter logic [Gain_Width-1:0] Kp_Acq  = 24'd419700,
    parameter logic [Gain_Width-1:0] Ki_Acq  = 24'd19600,

    // Loop gains - TRACK (payload): Bn_Ts = 0.015, zeta = 0.707, pipe_delay = 2
    // computed from compute_loop_gains.m (Q0.24)
    parameter logic [Gain_Width-1:0] Kp_Qpsk = 24'd180428,   // K_ted = 0.5
    parameter logic [Gain_Width-1:0] Ki_Qpsk = 24'd3609,
    parameter logic [Gain_Width-1:0] Kp_Qam  = 24'd324771,   // K_ted = 10*(1/6)^2
    parameter logic [Gain_Width-1:0] Ki_Qam  = 24'd6497,

    // Public lock detector parameters
    parameter int                      Lock_Alpha_Shift       = 4,
    parameter int                      Lock_Confirm_Count     = 12,
    parameter int                      Lock_Min_Symbols       = 15,
    parameter logic [Error_Width-1:0]  Lock_Init_Error        = 16'd8192,
    parameter logic [Error_Width-1:0]  Lock_Enter_Thresh_Qpsk = 16'd2064,
    parameter logic [Error_Width-1:0]  Lock_Exit_Thresh_Qpsk  = 16'd3277,
    parameter logic [Error_Width-1:0]  Lock_Enter_Thresh_Qam  = 16'd1147,
    parameter logic [Error_Width-1:0]  Lock_Exit_Thresh_Qam   = 16'd1820,

    // Internal lock detector parameters
    parameter int                      Lock_Int_Confirm_Count = 8,
    parameter logic [Error_Width-1:0]  Lock_Int_Enter_Thresh  = 16'd3600,
    parameter logic [Error_Width-1:0]  Lock_Int_Exit_Thresh   = 16'd5000,
    parameter int                      Lock_Int_Min_Symbols   = 4,
    parameter logic [Error_Width-1:0]  Lock_Int_Init_Error    = 16'd4000
)(
    input  logic                          clk_i,
    input  logic                          rst_ni,
    input  logic                          s_axis_valid_i,
    input  logic signed [Data_Width-1:0]  s_axis_i_sym_i,
    input  logic signed [Data_Width-1:0]  s_axis_q_sym_i,
    input  logic        [1:0]             mod_type_i,
    input  logic        [7:0]             costas_gain_i,
    input  logic        [1:0]             mode_i,                      // 00 HOLD, 01 ACQ, 10 TRACK
    input  logic                          slicer_qpsk_i,
    input  logic                          preamble_end_i,

    output logic                          freq_adj_valid_o,
    output logic signed [Phase_Width-1:0] freq_adj_o,
    output logic signed [Phase_Width-1:0] int_o,
    output logic                          phase_adj_valid_o,
    output logic        [Phase_Width-1:0] phase_adj_o,
    output logic                          quad_unresolved_o,
    output logic                          lock_o,
    output logic signed [Error_Width-1:0] dbg_e_o,                        // TED error (Q1.15)
    output logic                          dbg_e_valid_o,
    output logic                          dbg_lock_int_o,                // internal lock detector
    output logic                          dbg_quad_done_o                // quadrant decision made
);
    localparam logic [1:0] MODE_HOLD = 2'b00;
    localparam logic [1:0] MODE_ACQ  = 2'b01;
    localparam logic [1:0] MOD_QAM16 = 2'b01;

    // -------------------------------------- Reset Synchronizer (Async Assert, Sync Deassert)
    logic rst_meta_n, rst_sync_n;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rst_meta_n <= 1'b0;
            rst_sync_n <= 1'b0;
        end
        else begin
            rst_meta_n <= 1'b1;
            rst_sync_n <= rst_meta_n;
        end
    end

    // ------------------------------------------------ Slicer Subsystem
    logic signed [Data_Width-1:0] ai, aq;
    logic sgn_i_pos, sgn_q_pos;
    logic sgn_i_pos_q, sgn_q_pos_q;

    slicer #(
        .Data_Width   (Data_Width),
        .Qpsk_Level   (Qpsk_Level),
        .Qam_Level    (Qam_Level)
    ) u_slicer (
        .yi_i         (s_axis_i_sym_i),
        .yq_i         (s_axis_q_sym_i),
        .mod_type_i   (mod_type_i),
        .slicer_qpsk_i(slicer_qpsk_i),
        .ai_o         (ai),
        .aq_o         (aq),
        .sgn_i_pos_o  (sgn_i_pos),
        .sgn_q_pos_o  (sgn_q_pos)
    );

    // Pipeline delay to align signs with phase_error output valid
    always_ff @(posedge clk_i or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            sgn_i_pos_q <= 1'b0;
            sgn_q_pos_q <= 1'b0;
        end
        else if (s_axis_valid_i) begin
            sgn_i_pos_q <= sgn_i_pos;
            sgn_q_pos_q <= sgn_q_pos;
        end
    end

    // ------------------------------------------------ Gain/Threshold Config
    logic use_qam;
    logic [Gain_Width-1:0]  kp, ki;
    logic [Error_Width-1:0] thr_enter, thr_exit;

    always_comb begin
        use_qam = !slicer_qpsk_i && (mod_type_i == MOD_QAM16);

        if (mode_i == MODE_ACQ) begin
            kp = Kp_Acq;
            ki = Ki_Acq;
        end
        else begin
            kp = use_qam ? Kp_Qam : Kp_Qpsk;
            ki = use_qam ? Ki_Qam : Ki_Qpsk;
        end

        thr_enter = use_qam ? Lock_Enter_Thresh_Qam : Lock_Enter_Thresh_Qpsk;
        thr_exit  = use_qam ? Lock_Exit_Thresh_Qam  : Lock_Exit_Thresh_Qpsk;
    end

    // ------------------------------------------------ Phase Error Subsystem
    logic signed [Error_Width-1:0] e;
    logic e_valid;

    phase_error #(
        .Data_Width(Data_Width),
        .Error_Width(Error_Width),
        .Data_Frac_Bits(Data_Frac_Bits)
    ) u_pe (
        .clk_i  (clk_i),
        .rst_ni (rst_sync_n),
        .mode_i (mode_i),
        .valid_i(s_axis_valid_i),
        .yi_i   (s_axis_i_sym_i),
        .yq_i   (s_axis_q_sym_i),
        .ai_i   (ai),
        .aq_i   (aq),
        .e_o    (e),
        .valid_o(e_valid)
    );

    // ------------------------------------------------ PI Filter Subsystem
    logic pi_valid_unused;

    pi_filter #(
        .Error_Width    (Error_Width),
        .Gain_Width     (Gain_Width),
        .Phase_Width    (Phase_Width),
        .Error_Frac_Bits(Data_Frac_Bits),
        .Gain_Frac_Bits (Gain_Frac_Bits),
        .Max_Pi_Output  (Max_Pi_Output)
    ) u_pi (
        .clk_i     (clk_i),
        .rst_ni    (rst_sync_n),
        .mode_i    (mode_i),
        .valid_i   (e_valid),
        .e_i       (e),
        .kp_i      (kp),
        .ki_i      (ki),
        .freq_adj_o(freq_adj_o),
        .valid_o   (pi_valid_unused),
        .int_o     (int_o)
    );

    assign freq_adj_valid_o = (mode_i != MODE_HOLD);

    // ------------------------------------------------ Lock Detectors + Quad Check
    logic done, quad_unres;
    logic lock_int, lock_pub;

    lock_detector #(
        .Error_Width       (Error_Width),
        .Alpha_Shift       (Lock_Alpha_Shift),
        .Confirm_Count     (Lock_Int_Confirm_Count),
        .Min_Symbols       (Lock_Int_Min_Symbols),
        .Init_Error        (Lock_Int_Init_Error)
    ) u_lock_int (
        .clk_i      (clk_i),
        .rst_ni     (rst_sync_n),
        .clr_i      (mode_i == MODE_HOLD),
        .valid_i    (e_valid && !done),
        .e_i        (e),
        .thr_enter_i(Lock_Int_Enter_Thresh),
        .thr_exit_i (Lock_Int_Exit_Thresh),
        .locked_o   (lock_int)
    );

    quad_check #(
        .Phase_Width      (Phase_Width)
    ) u_quad (
        .clk_i            (clk_i),
        .rst_ni           (rst_sync_n),
        .mode_i           (mode_i),
        .valid_i          (e_valid),
        .sgn_i_pos_i      (sgn_i_pos_q),
        .sgn_q_pos_i      (sgn_q_pos_q),
        .lock_i           (lock_int),
        .preamble_end_i   (preamble_end_i),
        .phase_adj_valid_o(phase_adj_valid_o),
        .phase_adj_o      (phase_adj_o),
        .quad_unresolved_o(quad_unres),
        .done_o           (done)
    );

    lock_detector #(
        .Error_Width       (Error_Width),
        .Alpha_Shift       (Lock_Alpha_Shift),
        .Confirm_Count     (Lock_Confirm_Count),
        .Min_Symbols       (Lock_Min_Symbols),
        .Init_Error        (Lock_Init_Error)
    ) u_lock_pub (
        .clk_i      (clk_i),
        .rst_ni     (rst_sync_n),
        .clr_i      ((mode_i == MODE_HOLD) || !done || quad_unres),
        .valid_i    (e_valid),
        .e_i        (e),
        .thr_enter_i(thr_enter),
        .thr_exit_i (thr_exit),
        .locked_o   (lock_pub)
    );

    assign quad_unresolved_o = quad_unres;
    assign lock_o            = done && !quad_unres && lock_pub;
    assign dbg_e_o           = e;
    assign dbg_e_valid_o     = e_valid;
    assign dbg_lock_int_o    = lock_int;
    assign dbg_quad_done_o   = done;

endmodule
