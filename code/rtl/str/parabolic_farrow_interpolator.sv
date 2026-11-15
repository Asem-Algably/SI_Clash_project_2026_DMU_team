// Design Name:  Parabolic Farrow Interpolator (parabolic_farrow_interpolator)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
//
// 4-cycle pipelined Horner parabolic Farrow interpolator (alpha = 0.5):
//   v2 = 0.5 * (d - c - b + a)
//   v1 = 0.5 * (3*c - d - b - a)
//   h1 = v2 * mu + v1
//   y  = h1 * mu + b
//
// Output is signed 16-bit Q1.15 (sQ1.15).
// Resets are purely synchronous (active-low rst_n_i).

module parabolic_farrow_interpolator #(
    parameter integer DATA_IN_INTEGER_WIDTH    = 1,
    parameter integer DATA_IN_FRACTIONAL_WIDTH = 11,
    parameter integer DATA_OUT_INTEGER_WIDTH   = 1,
    parameter integer DATA_OUT_FRACTIONAL_WIDTH= 15,
    parameter integer MU_WIDTH                 = 10
)(
    input  logic                                  clk_i,
    input  logic                                  rst_n_i,
    input  logic                                  valid_sample_i,

    input  logic signed [11:0]                    x_i,   // sQ0.11 input sample
    input  logic        [MU_WIDTH-1:0]            mu_i,  // uQ0.10 fractional delay in [0, 1)

    output logic signed [15:0]                    y_o,   // sQ1.15 output symbol
    output logic                                  valid_sample_o
);

    // -------------------------------------------------------------------------
    // Stage 0: 5-tap delay line for past samples [s5, s4, s3, s2, s1]
    // Window [a, b, c, d] = [s5_q (t-3), s4_q (t-2), s3_q (t-1), s2_q (t)]
    // Perfectly aligns with 1-cycle registered mu_o and timing strobe from modulo_1_controller.
    // -------------------------------------------------------------------------
    logic signed [11:0] s1_q, s2_q, s3_q, s4_q, s5_q;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            s1_q <= '0;
            s2_q <= '0;
            s3_q <= '0;
            s4_q <= '0;
            s5_q <= '0;
        end else if (valid_sample_i) begin
            s1_q <= x_i;
            s2_q <= s1_q;
            s3_q <= s2_q;
            s4_q <= s3_q;
            s5_q <= s4_q;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 1: Polynomial coefficients v1, v2 and aligned b, mu
    // -------------------------------------------------------------------------
    logic signed [15:0] a12, b12, c12, d12;
    assign a12 = {{3{s5_q[11]}}, s5_q, 1'b0}; // sQ3.12 (sample t-3, oldest sample a)
    assign b12 = {{3{s4_q[11]}}, s4_q, 1'b0}; // sQ3.12 (sample t-2, center sample b)
    assign c12 = {{3{s3_q[11]}}, s3_q, 1'b0}; // sQ3.12 (sample t-1, forward sample c)
    assign d12 = {{3{s2_q[11]}}, s2_q, 1'b0}; // sQ3.12 (sample t, newest sample d)

    logic signed [15:0] v2_q; // sQ3.12
    logic signed [15:0] v1_q; // sQ3.12
    logic signed [15:0] b_s1;
    logic [MU_WIDTH-1:0] mu_s1;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            v2_q  <= '0;
            v1_q  <= '0;
            b_s1  <= '0;
            mu_s1 <= '0;
        end else if (valid_sample_i) begin
            // v2 = 0.5 * (d - c - b + a)
            v2_q  <= (d12 - c12 - b12 + a12) >>> 1;
            // v1 = 0.5 * (3*c - d - b - a)
            v1_q  <= ((c12 <<< 1) + c12 - d12 - b12 - a12) >>> 1;
            b_s1  <= b12;
            mu_s1 <= mu_i;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: First Horner stage: h1 = v2 * mu + v1
    // -------------------------------------------------------------------------
    logic signed [26:0] v2_x_mu;
    assign v2_x_mu = v2_q * $signed({1'b0, mu_s1}); // sQ3.12 * uQ0.10 = sQ4.22

    logic signed [16:0] h1_q; // sQ3.13
    logic signed [15:0] b_s2;
    logic [MU_WIDTH-1:0] mu_s2;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            h1_q  <= '0;
            b_s2  <= '0;
            mu_s2 <= '0;
        end else if (valid_sample_i) begin
            // Shift v2_x_mu right by 9 with pure wire truncation to get 13 frac bits; shift v1 left by 1
            h1_q  <= (v2_x_mu >>> 9) + (v1_q <<< 1);
            b_s2  <= b_s1;
            mu_s2 <= mu_s1;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Second Horner stage: y = h1 * mu + b (Output Q1.15)
    // -------------------------------------------------------------------------
    logic signed [27:0] h1_x_mu;
    assign h1_x_mu = h1_q * $signed({1'b0, mu_s2}); // sQ3.13 * uQ0.10 = sQ4.23

    logic signed [19:0] y_full;
    // Shift h1_x_mu right by 8 with pure wire truncation to get 15 frac bits
    assign y_full = (h1_x_mu >>> 8) + (b_s2 <<< 3); // 15 fractional bits

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            y_o <= '0;
        end else if (valid_sample_i) begin
            // Saturate to 16-bit signed Q1.15 [-32768, 32767]
            if (y_full > 20'sd32767) begin
                y_o <= 16'sh7FFF;
            end else if (y_full < -20'sd32768) begin
                y_o <= 16'sh8000;
            end else begin
                y_o <= y_full[15:0];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Valid pipeline: 4 clock cycles
    // -------------------------------------------------------------------------
    logic [3:0] val_pipe;
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            val_pipe <= '0;
        end else begin
            val_pipe <= {val_pipe[2:0], valid_sample_i};
        end
    end

    assign valid_sample_o = val_pipe[3];

endmodule
