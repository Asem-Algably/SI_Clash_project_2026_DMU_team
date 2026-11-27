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
    input  logic                                                          clk_i,
    input  logic                                                          rst_n_i,
    input  logic                                                          valid_sample_i,

    input  logic signed [DATA_IN_INTEGER_WIDTH+DATA_IN_FRACTIONAL_WIDTH-1:0]   x_i,   // sQ(IN_INT).(IN_FRAC) input sample
    input  logic        [MU_WIDTH-1:0]                                         mu_i,  // uQ0.(MU_WIDTH) fractional delay in [0, 1)

    output logic signed [DATA_OUT_INTEGER_WIDTH+DATA_OUT_FRACTIONAL_WIDTH-1:0] y_o,   // sQ(OUT_INT).(OUT_FRAC) output symbol
    output logic                                                               valid_sample_o
);

    localparam integer IN_WIDTH       = DATA_IN_INTEGER_WIDTH + DATA_IN_FRACTIONAL_WIDTH;
    localparam integer OUT_WIDTH      = DATA_OUT_INTEGER_WIDTH + DATA_OUT_FRACTIONAL_WIDTH;
    localparam integer V_FRAC         = DATA_IN_FRACTIONAL_WIDTH + 1;
    localparam integer V_WIDTH        = IN_WIDTH + 4;
    localparam integer H1_FRAC        = V_FRAC + 1;
    localparam integer H1_WIDTH       = V_WIDTH + 1;
    localparam integer V2_MU_WIDTH    = V_WIDTH + MU_WIDTH + 1;
    localparam integer H1_MU_WIDTH    = H1_WIDTH + MU_WIDTH + 1;
    localparam integer V2_TO_H1_SHIFT = (V_FRAC + MU_WIDTH) - H1_FRAC;
    localparam integer H1_TO_Y_SHIFT  = (H1_FRAC + MU_WIDTH) - DATA_OUT_FRACTIONAL_WIDTH;
    localparam integer B_TO_Y_SHIFT   = DATA_OUT_FRACTIONAL_WIDTH - V_FRAC;
    localparam integer Y_FULL_WIDTH   = OUT_WIDTH + 4;
    localparam integer PIPE_LATENCY   = 6;

    // -------------------------------------------------------------------------
    // Stage 0: 7-tap delay line for past samples [s7..s1]
    // Window [a, b, c, d] = [s7_q (t-5), s6_q (t-4), s5_q (t-3), s4_q (t-2)]
    // Aligns with the 3-stage pipelined (+2 cycle delay) mu_o and timing strobe from modulo_1_controller.
    // -------------------------------------------------------------------------
    logic signed [IN_WIDTH-1:0] s1_q, s2_q, s3_q, s4_q, s5_q, s6_q, s7_q;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            s1_q <= '0;
            s2_q <= '0;
            s3_q <= '0;
            s4_q <= '0;
            s5_q <= '0;
            s6_q <= '0;
            s7_q <= '0;
        end else if (valid_sample_i) begin
            s1_q <= x_i;
            s2_q <= s1_q;
            s3_q <= s2_q;
            s4_q <= s3_q;
            s5_q <= s4_q;
            s6_q <= s5_q;
            s7_q <= s6_q;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 1: Polynomial coefficients v1, v2 and aligned b, mu
    // -------------------------------------------------------------------------
    logic signed [V_WIDTH-1:0] a12, b12, c12, d12;
    assign a12 = {{3{s7_q[IN_WIDTH-1]}}, s7_q, 1'b0}; // sample t-5, oldest sample a
    assign b12 = {{3{s6_q[IN_WIDTH-1]}}, s6_q, 1'b0}; // sample t-4, center sample b
    assign c12 = {{3{s5_q[IN_WIDTH-1]}}, s5_q, 1'b0}; // sample t-3, forward sample c
    assign d12 = {{3{s4_q[IN_WIDTH-1]}}, s4_q, 1'b0}; // sample t-2, newest sample d

    logic signed [V_WIDTH-1:0] v2_q;
    logic signed [V_WIDTH-1:0] v1_q;
    logic signed [V_WIDTH-1:0] b_s1;
    logic [MU_WIDTH-1:0]       mu_s1;

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
    logic signed [V2_MU_WIDTH-1:0] v2_x_mu;
    logic signed [V2_MU_WIDTH-1:0] v2_mu_aligned;
    assign v2_x_mu = v2_q * $signed({1'b0, mu_s1});

    generate
        if (V2_TO_H1_SHIFT >= 0) begin : gen_v2_shr
            assign v2_mu_aligned = v2_x_mu >>> V2_TO_H1_SHIFT;
        end else begin : gen_v2_shl
            assign v2_mu_aligned = v2_x_mu <<< (-V2_TO_H1_SHIFT);
        end
    endgenerate

    logic signed [H1_WIDTH-1:0] h1_q;
    logic signed [V_WIDTH-1:0]  b_s2;
    logic [MU_WIDTH-1:0]        mu_s2;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            h1_q  <= '0;
            b_s2  <= '0;
            mu_s2 <= '0;
        end else if (valid_sample_i) begin
            // Shift v2_x_mu to H1_FRAC with pure wire truncation; shift v1 left by 1
            h1_q  <= v2_mu_aligned + (V2_MU_WIDTH'(v1_q) <<< 1);
            b_s2  <= b_s1;
            mu_s2 <= mu_s1;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Second Horner stage: y = h1 * mu + b (Output Q(OUT_INT).(OUT_FRAC))
    // -------------------------------------------------------------------------
    logic signed [H1_MU_WIDTH-1:0] h1_x_mu;
    logic signed [H1_MU_WIDTH-1:0] h1_mu_aligned, b_aligned;
    assign h1_x_mu = h1_q * $signed({1'b0, mu_s2});

    generate
        if (H1_TO_Y_SHIFT >= 0) begin : gen_h1_shr
            assign h1_mu_aligned = h1_x_mu >>> H1_TO_Y_SHIFT;
        end else begin : gen_h1_shl
            assign h1_mu_aligned = h1_x_mu <<< (-H1_TO_Y_SHIFT);
        end
        if (B_TO_Y_SHIFT >= 0) begin : gen_b_shl
            assign b_aligned = H1_MU_WIDTH'(b_s2) <<< B_TO_Y_SHIFT;
        end else begin : gen_b_shr
            assign b_aligned = H1_MU_WIDTH'(b_s2) >>> (-B_TO_Y_SHIFT);
        end
    endgenerate

    logic signed [Y_FULL_WIDTH-1:0] y_full;
    assign y_full = h1_mu_aligned + b_aligned;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            y_o <= '0;
        end else if (valid_sample_i) begin
            y_o <= y_full[OUT_WIDTH-1:0];
        end
    end

    // -------------------------------------------------------------------------
    // Valid pipeline: PIPE_LATENCY clock cycles
    // -------------------------------------------------------------------------
    logic [PIPE_LATENCY-1:0] val_pipe;
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            val_pipe <= '0;
        end else begin
            val_pipe <= {val_pipe[PIPE_LATENCY-2:0], valid_sample_i};
        end
    end

    assign valid_sample_o = val_pipe[PIPE_LATENCY-1];

endmodule
