// ============================================================================
// File Name   : pi_filter.sv
// Module Name : pi_filter
// Author      : Arwa Kantoush
// Description : Proportional-Integral (PI) loop filter with anti-windup.
//               3-stage pipeline generating frequency adjustment in Q0.32 format.
// ============================================================================
module pi_filter #(
    parameter int EW = 16,
    parameter int GW = 24,
    parameter int PW = 32,
    parameter int FE = 15,   // fractional bits of e_i (Q1.15)
    parameter int KF = 24,   // fractional bits of kp_i / ki_i (Q0.24)
    parameter logic signed [PW-1:0]MAX_V_PI = 32'sh1EB8_51EB  // 0.12 * 2^32 (Q0.32, turns/symbol)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic [1:0]mode_i,      // 00 HOLD, 01 ACQ, 10 TRACK
    input logic valid_i,
    input logic signed [EW-1:0]e_i,
    input logic [GW-1:0]kp_i,
    input logic [GW-1:0]ki_i,
    output logic signed [PW-1:0]freq_adj_o,
    output logic valid_o,
    output logic signed [PW-1:0]int_o
);
    localparam logic [1:0]MODE_HOLD = 2'b00;
    localparam int MW = EW + GW;                  // Multiplier width (Q1.39)
    localparam int SW = PW + 2;                   // Sum width (Q1.34)
    localparam int SHIFT = FE + KF - PW;          // Shift right to align to Q0.32
    localparam logic signed [MW-1:0]ROUND = (SHIFT > 0) ? (MW'(1) <<< ((SHIFT > 0) ? (SHIFT-1) : 0)) : '0; // Rounding constant for right shift

    // ---------------------------------------------------------------- sanity checks
    initial begin
        if (SHIFT < 0) begin
            $error("pi_filter: FE+KF must be >= PW");
        end
        if (MW - SHIFT > SW) begin
            $error("pi_filter: product does not fit SW");
        end
    end

    // ---------------------------------------------------------------- stage 1 (multiply + sign detection)
    logic signed [MW-1:0]p_prop_r, p_int_r;
    logic e_pos_1, e_neg_1;
    logic v1, v2;

    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            p_prop_r <= e_i * $signed({1'b0, kp_i}) + ROUND;   // Q(FE+KF)
            p_int_r <= e_i * $signed({1'b0, ki_i}) + ROUND;
            e_pos_1 <= !e_i[EW-1] && (e_i != '0);
            e_neg_1 <= e_i[EW-1];
        end
    end

    // ---------------------------------------------------------------- stage 2 (accumulate + anti-windup)
    logic signed [SW-1:0]p_prop_s, p_int_s, acc_sum, acc_cand, max_ext;
    logic signed [PW-1:0]acc_reg, v_pi_reg;
    logic signed [SW-1:0]acc_cand_r, p_prop_r2;
    logic e_pos_2, e_neg_2;

    //
    always_comb begin
        max_ext = SW'(MAX_V_PI);
        p_prop_s = SW'(p_prop_r >>> SHIFT);      // align to Q0.32 (just wiring, rounding is in ROUND)
        p_int_s = SW'(p_int_r >>> SHIFT);

        acc_sum = SW'(acc_reg) + p_int_s;
        acc_cand = acc_sum;
        if (acc_sum > max_ext) begin
            acc_cand = max_ext;
        end
        else if (acc_sum < -max_ext) begin
            acc_cand = -max_ext;
        end
    end

    always_ff @(posedge clk_i) begin
        if (v1) begin
            acc_cand_r <= acc_cand;
            p_prop_r2 <= p_prop_s;
            e_pos_2 <= e_pos_1;
            e_neg_2 <= e_neg_1;
        end
    end

    // ---------------------------------------------------------------- stage 3 (output register)
    logic signed [SW-1:0]v_sum;
    logic signed [PW-1:0]v_next;
    logic freeze, valid_reg;

    always_comb begin
        v_sum = acc_cand_r + p_prop_r2;
        v_next = v_sum[PW-1:0];
        if (v_sum > max_ext) begin
            v_next = MAX_V_PI;
        end
        else if (v_sum < -max_ext) begin
            v_next = -MAX_V_PI;
        end

        // Anti-windup: freeze the integrator if the output saturates in the error direction
        freeze = ((v_sum >  max_ext) && e_pos_2) || ((v_sum < -max_ext) && e_neg_2);
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            v1 <= 1'b0;
            v2 <= 1'b0;
            valid_reg <= 1'b0;
            acc_reg <= '0;
            v_pi_reg <= '0;
        end
        else if (mode_i == MODE_HOLD) begin
            v1 <= 1'b0;
            v2 <= 1'b0;
            valid_reg <= 1'b0;
            acc_reg <= '0;
            v_pi_reg <= '0;
        end
        else begin
            v1 <= valid_i;
            v2 <= v1;
            valid_reg <= v2;
            if (v2) begin
                acc_reg  <= (freeze)? acc_reg : acc_cand_r[PW-1:0];
                v_pi_reg <= v_next;
            end
        end
    end

    assign int_o = acc_reg;
    assign freq_adj_o = v_pi_reg;
    assign valid_o = valid_reg;

endmodule
