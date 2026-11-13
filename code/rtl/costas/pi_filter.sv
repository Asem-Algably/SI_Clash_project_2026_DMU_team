// ============================================================================
// File Name   : pi_filter.sv
// Module Name : pi_filter
// Author      : Arwa Kantoush
// Description : Proportional-Integral (PI) loop filter with anti-windup.
//               3-stage pipeline generating frequency adjustment in Q0.32 format.
//               Timing-optimised: each stage has ONE add + ONE compare at most.
//                 stage 1 : multiplies (DSP)
//                 stage 2 : integrator accumulate + clamp (1-cycle loop),
//                           proportional term aligned/registered
//                 stage 3 : v_sum = acc + prop, output clamp
//               Anti-windup freeze uses the saturation flags of the previous
//               sample (registered), so it is out of the integrator critical path.
//               Latency = 3 clocks. Back-to-back samples are accumulated correctly.
// ============================================================================
module pi_filter #(
    parameter int Error_Width     = 16,
    parameter int Gain_Width      = 24,
    parameter int Phase_Width     = 32,
    parameter int Error_Frac_Bits = 15,   // fractional bits of e_i (Q1.15)
    parameter int Gain_Frac_Bits  = 24,   // fractional bits of kp_i / ki_i (Q0.24)
    parameter logic signed [Phase_Width-1:0] Max_Pi_Output = 32'sh1EB8_51EB  // 0.12 * 2^32 (Q0.32, turns/symbol)
)(
    input  logic                          clk_i,
    input  logic                          rst_ni,
    input  logic        [1:0]             mode_i,      // 00 HOLD, 01 ACQ, 10 TRACK
    input  logic                          valid_i,
    input  logic signed [Error_Width-1:0] e_i,
    input  logic        [Gain_Width-1:0]  kp_i,
    input  logic        [Gain_Width-1:0]  ki_i,

    output logic signed [Phase_Width-1:0] freq_adj_o,
    output logic                          valid_o,
    output logic signed [Phase_Width-1:0] int_o
);
    localparam logic [1:0] MODE_HOLD = 2'b00;
    localparam int MW = Error_Width + Gain_Width;                           // Multiplier width (Q1.39)
    localparam int SW = Phase_Width + 2;                                    // Sum width (Q1.34)
    localparam int SHIFT = Error_Frac_Bits + Gain_Frac_Bits - Phase_Width;  // Shift right to align to Q0.32
    localparam logic signed [MW-1:0] ROUND = (SHIFT > 0) ? (MW'(1) <<< ((SHIFT > 0) ? (SHIFT-1) : 0)) : '0;

    // ---------------------------------------------------------------- stage 1 (multiply + sign detection)
    logic signed [MW-1:0] p_prop_r, p_int_r;
    logic e_pos_1, e_neg_1;
    logic v1, v2;

    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            p_prop_r <= e_i * $signed({1'b0, kp_i}) + ROUND;
            p_int_r  <= e_i * $signed({1'b0, ki_i}) + ROUND;
            e_pos_1  <= !e_i[Error_Width-1] && (e_i != '0);
            e_neg_1  <= e_i[Error_Width-1];
        end
    end

    // ---------------------------------------------------------------- stage 2 (integrator loop: add + clamp only)
    logic signed [SW-1:0]          max_ext, p_int_s, acc_sum, acc_cand;
    logic signed [SW-1:0]          p_prop_q;           // proportional term, aligned, registered in stage 2
    logic signed [Phase_Width-1:0] acc_reg, acc_out, v_pi_reg;
    logic                          sat_pos_q, sat_neg_q; // output saturation of the previous sample
    logic                          freeze;

    always_comb begin
        max_ext  = SW'(Max_Pi_Output);
        p_int_s  = SW'(p_int_r >>> SHIFT);               // align to Q0.32 (rounding is in ROUND)

        acc_sum  = SW'(acc_reg) + p_int_s;
        acc_cand = acc_sum;
        if (acc_sum > max_ext) begin
            acc_cand = max_ext;
        end
        else if (acc_sum < -max_ext) begin
            acc_cand = -max_ext;
        end

        // Anti-windup: stop integrating if the output was already saturated in the error direction
        freeze = (sat_pos_q && e_pos_1) || (sat_neg_q && e_neg_1);
    end

    // proportional term: wiring only (shift) + register, no reset needed
    always_ff @(posedge clk_i) begin
        if (v1) begin
            p_prop_q <= SW'(p_prop_r >>> SHIFT);
        end
    end

    // ---------------------------------------------------------------- stage 3 (v_sum = acc + prop, output clamp)
    logic signed [SW-1:0] v_sum;

    always_comb begin
        v_sum = SW'(acc_reg) + p_prop_q;                 // acc_reg / p_prop_q still hold THIS sample here
    end

    // ---------------------------------------------------------------- control / state registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            v1        <= 1'b0;
            v2        <= 1'b0;
            valid_o   <= 1'b0;
            acc_reg   <= '0;
            acc_out   <= '0;
            v_pi_reg  <= '0;
            sat_pos_q <= 1'b0;
            sat_neg_q <= 1'b0;
        end
        else if (mode_i == MODE_HOLD) begin
            v1        <= 1'b0;
            v2        <= 1'b0;
            valid_o   <= 1'b0;
            acc_reg   <= '0;
            acc_out   <= '0;
            v_pi_reg  <= '0;
            sat_pos_q <= 1'b0;
            sat_neg_q <= 1'b0;
        end
        else begin
            v1      <= valid_i;
            v2      <= v1;
            valid_o <= v2;

            if (v1) begin                                   // stage 2
                if (!freeze) begin
                    acc_reg <= acc_cand[Phase_Width-1:0];
                end
            end

            if (v2) begin                                   // stage 3
                if (v_sum > max_ext) begin
                    v_pi_reg  <= Max_Pi_Output;
                    sat_pos_q <= 1'b1;
                    sat_neg_q <= 1'b0;
                end
                else if (v_sum < -max_ext) begin
                    v_pi_reg  <= -Max_Pi_Output;
                    sat_pos_q <= 1'b0;
                    sat_neg_q <= 1'b1;
                end
                else begin
                    v_pi_reg  <= v_sum[Phase_Width-1:0];
                    sat_pos_q <= 1'b0;
                    sat_neg_q <= 1'b0;
                end
                acc_out <= acc_reg;                         // acc after this sample (aligned with valid_o)
            end
        end
    end

    assign int_o      = acc_out;
    assign freq_adj_o = v_pi_reg;

endmodule
