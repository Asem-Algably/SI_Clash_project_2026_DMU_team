// Design Name:  Modulo-1 Controller / NCO (modulo_1_controller)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
//
// Generates mid and current strobes, decrements the Modulo-1 phase counter M,
// and computes the fractional delay mu in [0, 1) using Taylor expansion:
//   mu = 4*eta - 16*eta*v_pi
// 24-bit unsigned NCO (uQ0.24) with nominal step W_NOM = 0.25 (24'h40_0000).
// Resets are purely synchronous (active-low rst_ni).

module modulo_1_controller #(
    parameter integer MU_WIDTH    = 10,
    parameter integer NCO_WIDTH   = 24,
    parameter integer PI_WIDTH    = 24,
    parameter integer W_OUT_WIDTH = 16,
    parameter logic [NCO_WIDTH-1:0] M_INIT = 24'hC0_0000, // 0.75 in uQ0.24
    parameter logic [NCO_WIDTH-1:0] W_NOM  = 24'h40_0000, // 0.25 in uQ0.24
    parameter logic [NCO_WIDTH-1:0] Q25    = 24'h40_0000, // 0.25 in uQ0.24
    parameter logic [NCO_WIDTH-1:0] Q75    = 24'hC0_0000  // 0.75 in uQ0.24
)(
    input  logic                        clk_i,
    input  logic                        rst_ni,          // Synchronous active-low reset
    input  logic                        valid_sample_i,  // ce_str clock enable

    input  logic signed [PI_WIDTH-1:0]  pi_i,            // Signed PI correction

    output logic [MU_WIDTH-1:0]         mu_o,            // uQ0.(MU_WIDTH) fractional delay in [0, 1)
    output logic                        mid_strobe_o,    // Mid-symbol strobe
    output logic                        current_strobe_o,// Symbol strobe
    output logic signed [W_OUT_WIDTH-1:0] w_o            // Step size for DFT observation
);

    localparam integer MULT_WIDTH  = NCO_WIDTH + PI_WIDTH;
    localparam integer TERM2_SHIFT = NCO_WIDTH - 4;
    localparam integer MU_FULL_W   = NCO_WIDTH + 1;
    localparam logic signed [NCO_WIDTH+1:0] ONE_FULL = (NCO_WIDTH+2)'(1) <<< NCO_WIDTH;

    // -------------------------------------------------------------------------
    // W calculation: W = W_NOM + pi_i (uQ0.(NCO_WIDTH))
    // -------------------------------------------------------------------------
    logic [NCO_WIDTH-1:0] w_val;
    assign w_val = W_NOM + NCO_WIDTH'(pi_i);
    assign w_o   = w_val[NCO_WIDTH-1 -: W_OUT_WIDTH]; // Convert for observation port

    // -------------------------------------------------------------------------
    // Modulo-1 Counter M and Region Crossing Logic
    // -------------------------------------------------------------------------
    logic [NCO_WIDTH-1:0] m_q;
    logic [NCO_WIDTH-1:0] m_next;
    assign m_next = m_q - w_val; // Unsigned subtraction wraps mod 1.0

    logic in_mid_old, in_mid_new;
    assign in_mid_old = (m_q >= Q25) && (m_q < Q75);
    assign in_mid_new = (m_next >= Q25) && (m_next < Q75);

    logic                 new_cur, new_mid;
    logic [NCO_WIDTH-1:0] eta_raw;

    always_comb begin
        new_cur = 1'b0;
        new_mid = 1'b0;
        eta_raw = '0;

        if (in_mid_old && !in_mid_new) begin
            new_cur = 1'b1;
            eta_raw = m_q - Q25;
        end else if (!in_mid_old && in_mid_new) begin
            new_mid = 1'b1;
            if (m_q >= Q75) begin
                eta_raw = m_q - Q75;
            end else begin
                eta_raw = m_q + Q25; // m_q - (Q75 - 1.0) = m_q + 0.25
            end
        end
    end

    // -------------------------------------------------------------------------
    // Fractional Delay mu calculation: mu = 4*eta - 16*eta*pi
    // 3-Stage Pipelined Architecture (2 Cuts) to achieve 200 MHz timing closure:
    //   Stage 1 (Cut 1): Register eta_raw, pi_i, eta_4x, and strobe flags (AREG=1, BREG=1)
    //   Stage 2 (Cut 2): Register cascaded DSP product eta_pi_mult_q & strobes (PREG=1)
    //   Stage 3: Subtraction, saturation clamping, and registered outputs (mu_reg, strobes)
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Stage 1 Registers (Cut 1: DSP Inputs)
    // -------------------------------------------------------------------------
    logic [NCO_WIDTH-1:0]      eta_raw_q;
    logic signed [PI_WIDTH-1:0] pi_q;
    logic [NCO_WIDTH-1:0]      eta_4x_q1;
    logic                      strobe_cur_q1;
    logic                      strobe_mid_q1;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            m_q           <= M_INIT;
            eta_raw_q     <= '0;
            pi_q          <= '0;
            eta_4x_q1     <= '0;
            strobe_cur_q1 <= 1'b0;
            strobe_mid_q1 <= 1'b0;
        end else if (valid_sample_i) begin
            m_q           <= m_next;
            eta_raw_q     <= eta_raw;
            pi_q          <= pi_i;
            eta_4x_q1     <= eta_raw <<< 2; // 4 * eta
            strobe_cur_q1 <= new_cur;
            strobe_mid_q1 <= new_mid;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2 Registers (Cut 2: DSP Output)
    // -------------------------------------------------------------------------
    logic signed [MULT_WIDTH-1:0] eta_pi_mult_q;
    logic [NCO_WIDTH-1:0]         eta_4x_q2;
    logic                         strobe_cur_q2;
    logic                         strobe_mid_q2;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            eta_pi_mult_q <= '0;
            eta_4x_q2     <= '0;
            strobe_cur_q2 <= 1'b0;
            strobe_mid_q2 <= 1'b0;
        end else if (valid_sample_i) begin
            eta_pi_mult_q <= $signed({1'b0, eta_raw_q}) * pi_q;
            eta_4x_q2     <= eta_4x_q1;
            strobe_cur_q2 <= strobe_cur_q1;
            strobe_mid_q2 <= strobe_mid_q1;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Arithmetic, Saturation, and Output Registers
    // -------------------------------------------------------------------------
    logic signed [NCO_WIDTH-1:0] term2;
    assign term2 = NCO_WIDTH'(eta_pi_mult_q >>> TERM2_SHIFT); // Signed arithmetic shift aligned with NCO_WIDTH

    logic signed [MU_FULL_W-1:0] mu_full;
    assign mu_full = $signed({1'b0, eta_4x_q2}) - $signed({{1{term2[NCO_WIDTH-1]}}, term2});

    logic [MU_WIDTH-1:0] mu_calc;
    always_comb begin
        if (mu_full < 0) begin
            mu_calc = '0;
        end else if ($signed(mu_full) >= ONE_FULL) begin // >= 1.0
            mu_calc = {MU_WIDTH{1'b1}};
        end else begin
            // Extract top MU_WIDTH fractional bits
            mu_calc = mu_full[NCO_WIDTH-1 -: MU_WIDTH];
        end
    end

    // -------------------------------------------------------------------------
    // Sequential Output Registers (Synchronous Reset, Gated by valid_sample_i)
    // -------------------------------------------------------------------------
    logic [MU_WIDTH-1:0] mu_reg;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            mid_strobe_o     <= 1'b0;
            current_strobe_o <= 1'b0;
            mu_reg           <= '0;
        end else if (valid_sample_i) begin
            mid_strobe_o     <= strobe_mid_q2;
            current_strobe_o <= strobe_cur_q2;
            if (strobe_cur_q2 || strobe_mid_q2) begin
                mu_reg <= mu_calc;
            end
        end
        // When valid_sample_i = 0: completely freeze state (matching MATLAB st = st_old)
    end

    assign mu_o = mu_reg;

endmodule
