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
    parameter int                           ErrInWidth     = 32,
    parameter int                           ErrActiveWidth = 25,
    parameter int                           ErrFracBits    = 21,
    parameter int                           GainWidth      = 24,
    parameter int                           KpFracBits     = 25,
    parameter int                           KiFracBits     = 31,
    parameter int                           PiIntWidth     = 26,
    parameter int                           PiIntFracBits  = 28,
    parameter int                           PiOutWidth     = 24,
    parameter int                           PiOutFracBits  = 24,
    parameter logic [GainWidth-1:0]         KP             = 24'h0A_EDD7,
    parameter logic [GainWidth-1:0]         KI             = 24'h09_53F9,
    parameter logic signed [PiIntWidth-1:0] MAX_V_PI       = 26'sh08F_5C29 // +-0.0350 in sQ-3.28 (int 9395241)
)(
    input  logic                        clk_i,
    input  logic                        rst_ni,     // Synchronous active-low reset
    input  logic                        valid_i,    // TED error valid strobe & ce_str
    input  logic signed [ErrInWidth-1:0] error_i,    // Signed error from Gardner TED
    output logic signed [PiOutWidth-1:0] pi_o        // Filtered loop correction to Modulo-1 NCO (latency = 2)
);

    localparam int MultWidth = GainWidth + 1 + ErrActiveWidth;
    localparam int SumWidth  = PiIntWidth + 1;
    localparam int PShift    = (KpFracBits + ErrFracBits) - PiIntFracBits;
    localparam int IShift    = (KiFracBits + ErrFracBits) - PiIntFracBits;
    localparam int OutShift  = PiIntFracBits - PiOutFracBits;
    localparam logic signed [SumWidth-1:0] MaxVPiExt = SumWidth'(MAX_V_PI);

    // Extract active signed error bits
    logic signed [ErrActiveWidth-1:0] e_s21;
    assign e_s21 = error_i[ErrActiveWidth-1:0];

    // -------------------------------------------------------------------------
    // Stage 1: Registered Multipliers Kp * e and Ki * e (1 clock cycle)
    // -------------------------------------------------------------------------
    logic signed [MultWidth-1:0]      kp_mult_q;
    logic signed [MultWidth-1:0]      ki_mult_q;
    logic signed [ErrActiveWidth-1:0] e_stg1_q;
    logic                             v_stg1_q;

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
    logic signed [PiIntWidth-1:0] p_term;
    assign p_term = PiIntWidth'(kp_mult_q >>> PShift); // proper arithmetic shift

    logic signed [PiIntWidth-1:0] i_term;
    assign i_term = PiIntWidth'(ki_mult_q >>> IShift); // proper arithmetic shift

    logic signed [PiIntWidth-1:0] acc_q;
    logic signed [SumWidth-1:0]   acc_sum;
    assign acc_sum = acc_q + i_term;

    logic signed [PiIntWidth-1:0] acc_clamped;
    always_comb begin
        if (acc_sum > MaxVPiExt) begin
            acc_clamped = MAX_V_PI;
        end else if (acc_sum < -MaxVPiExt) begin
            acc_clamped = -MAX_V_PI;
        end else begin
            acc_clamped = acc_sum[PiIntWidth-1:0];
        end
    end

    // Proportional + Clamped Integral
    logic signed [SumWidth-1:0] v_raw;
    assign v_raw = p_term + acc_clamped;

    // Output Saturation
    logic signed [PiIntWidth-1:0] v_pi;
    logic                         sat_hi, sat_lo;
    assign sat_hi = (v_raw > MaxVPiExt);
    assign sat_lo = (v_raw < -MaxVPiExt);

    always_comb begin
        if (sat_hi) begin
            v_pi = MAX_V_PI;
        end else if (sat_lo) begin
            v_pi = -MAX_V_PI;
        end else begin
            v_pi = v_raw[PiIntWidth-1:0];
        end
    end

    // Sequential State Registers (Synchronous Reset)
    logic signed [PiIntWidth-1:0] pi_reg_q;

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

    // Scale internal PI word to PiOutWidth
    assign pi_o = PiOutWidth'($signed(pi_reg_q) >>> OutShift);

endmodule
