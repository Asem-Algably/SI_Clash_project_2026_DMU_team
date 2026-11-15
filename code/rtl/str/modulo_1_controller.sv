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
    parameter integer MU_WIDTH = 10
)(
    input  logic                     clk_i,
    input  logic                     rst_ni,          // Synchronous active-low reset
    input  logic                     valid_sample_i,  // ce_str clock enable

    input  logic signed [23:0]       pi_i,            // sQ-1.24 from PI filter

    output logic [MU_WIDTH-1:0]      mu_o,            // uQ0.10 fractional delay in [0, 1)
    output logic                     mid_strobe_o,    // Mid-symbol strobe
    output logic                     current_strobe_o,// Symbol strobe
    output logic signed [15:0]       w_o              // Step size for DFT observation (sQ1.15)
);

    localparam logic [23:0] M_INIT = 24'hC0_0000; // 0.75 in uQ0.24
    localparam logic [23:0] W_NOM  = 24'h40_0000; // 0.25 in uQ0.24
    localparam logic [23:0] Q25    = 24'h40_0000; // 0.25 in uQ0.24
    localparam logic [23:0] Q75    = 24'hC0_0000; // 0.75 in uQ0.24

    // -------------------------------------------------------------------------
    // W calculation: W = W_NOM + pi_i (uQ0.24)
    // -------------------------------------------------------------------------
    logic [23:0] w_val;
    assign w_val = W_NOM + pi_i;
    assign w_o   = w_val[23:8]; // Convert to Q1.15 for observation port

    // -------------------------------------------------------------------------
    // Modulo-1 Counter M and Region Crossing Logic
    // -------------------------------------------------------------------------
    logic [23:0] m_q;
    logic [23:0] m_next;
    assign m_next = m_q - w_val; // Unsigned 24-bit subtraction wraps mod 1.0

    logic in_mid_old, in_mid_new;
    assign in_mid_old = (m_q >= Q25) && (m_q < Q75);
    assign in_mid_new = (m_next >= Q25) && (m_next < Q75);

    logic        new_cur, new_mid;
    logic [23:0] eta_raw;

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
    // eta is uQ0.24. 4*eta is eta <<< 2 (uQ0.22 integer equivalent).
    // -------------------------------------------------------------------------
    logic [23:0] eta_4x;
    assign eta_4x = eta_raw <<< 2; // 4 * eta (uQ0.24)

    logic signed [47:0] eta_pi_mult;
    assign eta_pi_mult = $signed({1'b0, eta_raw}) * pi_i; // uQ0.24 * sQ-1.24 = sQ-1.48

    // 16 * eta * pi: eta_pi_mult has 48 fractional bits. Multiplying by 16 and formatting to 24 frac bits gives >>> 20
    logic signed [23:0] term2;
    assign term2 = 24'(eta_pi_mult >>> 20); // Signed arithmetic shift aligned with uQ0.24

    logic signed [24:0] mu_full;
    assign mu_full = $signed({1'b0, eta_4x}) - $signed({{1{term2[23]}}, term2});

    logic [MU_WIDTH-1:0] mu_calc;
    always_comb begin
        if (mu_full < 0) begin
            mu_calc = '0;
        end else if (mu_full >= 26'sd16777216) begin // >= 1.0 in 26-bit signed
            mu_calc = {MU_WIDTH{1'b1}};
        end else begin
            // Extract top MU_WIDTH fractional bits [23 : 24-MU_WIDTH]
            mu_calc = mu_full[23 -: MU_WIDTH];
        end
    end

    // -------------------------------------------------------------------------
    // Sequential State Registers (Synchronous Reset)
    // -------------------------------------------------------------------------
    logic [MU_WIDTH-1:0] mu_reg;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            m_q              <= M_INIT;
            mid_strobe_o     <= 1'b0;
            current_strobe_o <= 1'b0;
            mu_reg           <= '0;
        end else if (valid_sample_i) begin
            m_q              <= m_next;
            mid_strobe_o     <= new_mid;
            current_strobe_o <= new_cur;
            if (new_cur || new_mid) begin
                mu_reg <= mu_calc;
            end
        end
        // When valid_sample_i = 0: completely freeze state (matching MATLAB st = st_old)
    end

    assign mu_o = mu_reg;

endmodule
