// ============================================================================
// File Name   : costas_top.sv
// Module Name : costas_top
// Author      : Arwa Kantoush
// Description : Top-level Costas Loop Subsystem wrapper incorporating slicer,
//               phase detector, PI filter, dual lock detectors, and quad check.
// ============================================================================
module costas_top #(
    parameter int W = 16,
    parameter int EW = 16,
    parameter int GW = 24,
    parameter int PW = 32,
    parameter int FRAC = 15,
    parameter int KF = 24,
    parameter logic signed [PW-1:0]MAX_V_PI = 32'sh1EB8_51EB,

    parameter logic signed [W-1:0]D_QPSK = 16'sd16384,
    parameter logic signed [W-1:0]D_QAM  = 16'sd5461,

    // Loop gains
    parameter logic [GW-1:0]KP_QPSK = 24'd299803,
    parameter logic [GW-1:0]KI_QPSK = 24'd9995,
    parameter logic [GW-1:0]KP_QAM = 24'd539646,
    parameter logic [GW-1:0]KI_QAM = 24'd17992,

    // Lock detector parameters
    parameter int LD_K = 4,
    parameter int LD_CONFIRM = 20,
    parameter int LD_MIN_SYM = 15,
    parameter logic [EW-1:0]LD_M_INIT = 16'd8192,
    parameter logic [EW-1:0]THR_ENTER_QPSK = 16'd2064,
    parameter logic [EW-1:0]THR_EXIT_QPSK = 16'd3277,
    parameter logic [EW-1:0]THR_ENTER_QAM = 16'd1147,
    parameter logic [EW-1:0]THR_EXIT_QAM = 16'd1820
)(
    input logic clk_i,
    input logic rst_ni,
    input logic s_axis_valid_i,
    input logic signed [W-1:0]s_axis_i_sym_i,
    input logic signed [W-1:0]s_axis_q_sym_i,
    input logic [1:0]mod_type_i,
    input logic [7:0]costas_gain_i,
    input logic [1:0]mode_i,            // 00 HOLD, 01 ACQ, 10 TRACK
    input logic slicer_qpsk_i,
    input logic preamble_end_i,

    output logic freq_adj_valid_o,
    output logic signed [PW-1:0]freq_adj_o,
    output logic signed [PW-1:0]int_o,
    output logic phase_adj_valid_o,
    output logic [PW-1:0]phase_adj_o,
    output logic quad_unresolved_o,
    output logic lock_o,
    output logic signed [EW-1:0]dbg_e_o,        // TED error (Q1.15)
    output logic dbg_e_valid_o,
    output logic dbg_lock_int_o,                // internal lock detector
    output logic dbg_quad_done_o                // quadrant decision made
);
    localparam logic [1:0]MODE_HOLD = 2'b00;
    localparam logic [1:0]MOD_QAM16 = 2'b01;

    // ------------------------------------------------ Slicer Subsystem
    logic signed [W-1:0]ai, aq;
    logic sgn_i_pos, sgn_q_pos;
    logic sgn_i_pos_q, sgn_q_pos_q;

    slicer #(.W(W), .D_QPSK(D_QPSK), .D_QAM(D_QAM)) u_slicer (
        .yi_i(s_axis_i_sym_i), .yq_i(s_axis_q_sym_i),
        .mod_type_i(mod_type_i), .slicer_qpsk_i(slicer_qpsk_i),
        .ai_o(ai), .aq_o(aq),
        .sgn_i_pos_o(sgn_i_pos), .sgn_q_pos_o(sgn_q_pos)
    );

    // Pipeline delay to align signs with phase_error output valid
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
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
    logic [GW-1:0]kp, ki;
    logic [EW-1:0]thr_enter, thr_exit;

    always_comb begin
        use_qam = !slicer_qpsk_i && (mod_type_i == MOD_QAM16);
        kp = use_qam ? KP_QAM : KP_QPSK;
        ki = use_qam ? KI_QAM : KI_QPSK;
        thr_enter = use_qam ? THR_ENTER_QAM : THR_ENTER_QPSK;
        thr_exit = use_qam ? THR_EXIT_QAM : THR_EXIT_QPSK;
    end

    // ------------------------------------------------ Phase Error Subsystem
    logic signed [EW-1:0]e;
    logic e_valid;

    phase_error #(.W(W), .EW(EW), .FRAC(FRAC)) u_pe (
        .clk_i(clk_i), .rst_ni(rst_ni), .mode_i(mode_i),
        .valid_i(s_axis_valid_i),
        .yi_i(s_axis_i_sym_i), .yq_i(s_axis_q_sym_i),
        .ai_i(ai), .aq_i(aq),
        .e_o(e), .valid_o(e_valid)
    );

    // ------------------------------------------------ PI Filter Subsystem
    logic pi_valid_unused;

    pi_filter #(.EW(EW), .GW(GW), .PW(PW), .FE(FRAC), .KF(KF), .MAX_V_PI(MAX_V_PI)) u_pi (
        .clk_i(clk_i), .rst_ni(rst_ni), .mode_i(mode_i),
        .valid_i(e_valid), .e_i(e),
        .kp_i(kp), .ki_i(ki),
        .freq_adj_o(freq_adj_o), .valid_o(pi_valid_unused), .int_o(int_o)
    );

    assign freq_adj_valid_o = (mode_i != MODE_HOLD);

    // ------------------------------------------------ Lock Detectors + Quad Check
    logic done, quad_unres;
    logic lock_int, lock_pub;

    lock_detector #(.EW(EW), .K(LD_K), .CONFIRM(LD_CONFIRM), .MIN_SYM(LD_MIN_SYM), .M_INIT(LD_M_INIT)) u_lock_int (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .clr_i(mode_i == MODE_HOLD),
        .valid_i(e_valid && !done),
        .e_i(e), .thr_enter_i(thr_enter), .thr_exit_i(thr_exit),
        .locked_o(lock_int)
    );

    quad_check #(.PW(PW)) u_quad (
        .clk_i(clk_i), .rst_ni(rst_ni), .mode_i(mode_i),
        .valid_i(e_valid),
        .sgn_i_pos_i(sgn_i_pos_q), .sgn_q_pos_i(sgn_q_pos_q),
        .lock_i(lock_int), .preamble_end_i(preamble_end_i),
        .phase_adj_valid_o(phase_adj_valid_o), .phase_adj_o(phase_adj_o),
        .quad_unresolved_o(quad_unres), .done_o(done)
    );

    lock_detector #(.EW(EW), .K(LD_K), .CONFIRM(LD_CONFIRM), .MIN_SYM(LD_MIN_SYM), .M_INIT(LD_M_INIT)) u_lock_pub (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .clr_i((mode_i == MODE_HOLD) || !done || quad_unres),
        .valid_i(e_valid),
        .e_i(e), .thr_enter_i(thr_enter), .thr_exit_i(thr_exit),
        .locked_o(lock_pub)
    );

    assign quad_unresolved_o = quad_unres;
    assign lock_o = done && !quad_unres && lock_pub;
    assign dbg_e_o = e;
    assign dbg_e_valid_o = e_valid;
    assign dbg_lock_int_o = lock_int;
    assign dbg_quad_done_o = done;

endmodule
