// Design Name:  STR PI Loop Filter (pI_loop)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
//
// Filters the timing error from the Gardner TED (sQ3.21):
//   Kp = 24'h0A_EDD7 (uQ-1.25)
//   Ki = 24'h09_53F9 (uQ-7.31)
//   Clamp limit = +-0.0350 (26'sh08F_5C29 in sQ-3.28)
// 2-Stage Pipelined Architecture (Latency = 2 clock cycles):
//   Stage 1: Register multiplier products Kp * e and Ki * e
//   Stage 2: Accumulate integral term, apply anti-windup clamping, and register pi_o
// Resets are purely synchronous (active-low rst_ni).

module pI_loop #(
    parameter logic [23:0]        KP        = 24'h0A_EDD7,
    parameter logic [23:0]        KI        = 24'h09_53F9,
    parameter logic signed [25:0] MAX_V_PI  = 26'sh08F_5C29 // +-0.0350 in sQ-3.28 (int 9395241)
)(
    input  logic               clk_i,
    input  logic               rst_ni,     // Synchronous active-low reset
    input  logic               valid_i,    // TED error valid strobe & ce_str
    input  logic signed [31:0] error_i,    // sQ3.21 from Gardner TED
    output logic signed [23:0] pi_o        // sQ-1.24 to Modulo-1 NCO (latency = 2)
);

    // Extract 25-bit sQ3.21 error
    logic signed [24:0] e_s21;
    assign e_s21 = error_i[24:0];

    // -------------------------------------------------------------------------
    // Stage 1: Registered Multipliers Kp * e and Ki * e (1 clock cycle)
    // -------------------------------------------------------------------------
    // Kp (25 frac) * e (21 frac) = 46 frac bits
    // Ki (31 frac) * e (21 frac) = 52 frac bits
    logic signed [49:0] kp_mult_q;
    logic signed [49:0] ki_mult_q;
    logic signed [24:0] e_stg1_q;
    logic               v_stg1_q;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            v_stg1_q  <= 1'b0;
            kp_mult_q <= '0;
            ki_mult_q <= '0;
            e_stg1_q  <= '0;
        end else begin
            v_stg1_q <= valid_i;
            if (valid_i) begin
                kp_mult_q <= $signed({1'b0, KP}) * e_s21;
                ki_mult_q <= $signed({1'b0, KI}) * e_s21;
                e_stg1_q  <= e_s21;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: Combinational Scaling, Clamping, and State Registers (2 clocks)
    // -------------------------------------------------------------------------
    logic signed [25:0] p_term;
    assign p_term = 26'(kp_mult_q >>> 18); // sQ-3.28 with proper arithmetic shift

    logic signed [25:0] i_term;
    assign i_term = 26'(ki_mult_q >>> 24); // sQ-3.28 with proper arithmetic shift

    logic signed [25:0] acc_q;
    logic signed [26:0] acc_sum;
    assign acc_sum = acc_q + i_term;

    logic signed [25:0] acc_clamped;
    always_comb begin
        if (acc_sum > $signed({1'b0, MAX_V_PI})) begin
            acc_clamped = MAX_V_PI;
        end else if (acc_sum < -MAX_V_PI) begin
            acc_clamped = -MAX_V_PI;
        end else begin
            acc_clamped = acc_sum[25:0];
        end
    end

    // Proportional + Clamped Integral
    logic signed [26:0] v_raw;
    assign v_raw = p_term + acc_clamped;

    // Output Saturation
    logic signed [25:0] v_pi;
    logic               sat_hi, sat_lo;
    assign sat_hi = (v_raw > $signed({1'b0, MAX_V_PI}));
    assign sat_lo = (v_raw < -MAX_V_PI);

    always_comb begin
        if (sat_hi) begin
            v_pi = MAX_V_PI;
        end else if (sat_lo) begin
            v_pi = -MAX_V_PI;
        end else begin
            v_pi = v_raw[25:0];
        end
    end

    // Sequential State Registers (Synchronous Reset)
    logic signed [25:0] pi_reg_q;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            acc_q    <= '0;
            pi_reg_q <= '0;
        end else if (v_stg1_q) begin
            // Conditional Anti-Windup: freeze accumulator if saturated in direction of error
            if (sat_hi && (e_stg1_q > 0)) begin
                acc_q <= acc_q; // Freeze
            end else if (sat_lo && (e_stg1_q < 0)) begin
                acc_q <= acc_q; // Freeze
            end else begin
                acc_q <= acc_clamped;
            end
            pi_reg_q <= v_pi;
        end
    end

    // pi_o is sQ-1.24 (shift signed sQ-3.28 right by 4 bits with proper sign extension)
    assign pi_o = 24'($signed(pi_reg_q) >>> 4);

endmodule
