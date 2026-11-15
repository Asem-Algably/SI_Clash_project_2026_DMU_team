// Design Name:  Symbol Timing Recovery Top (str_top)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
//
// Structural top level of the STR subsystem:
//   1. Parabolic Farrow Interpolators (I and Q branches, 4 cycles latency, sQ1.15)
//   2. 4-Stage Strobe Alignment Pipeline
//   3. Gardner Timing Error Detector (sQ3.21)
//   4. Proportional-Integral (PI) Loop Filter
//   5. Modulo-1 NCO Controller
//   6. STR Lock Detector
//
// Output symbols are signed 16-bit Q1.15 (sQ1.15).
// Resets are purely synchronous (active-low rst_ni).

module str_top (
    input  logic         clk_i,
    input  logic         rst_ni,             // Synchronous active-low reset
    input  logic         s_axis_valid_i,
    input  logic         flush_active_i,
    input  logic [11:0]  s_axis_i_sample_i,
    input  logic [11:0]  s_axis_q_sample_i,
    input  logic [7:0]   loop_gain_i,
    output logic         m_axis_valid_o,
    output logic [15:0]  m_axis_i_sym_o,
    output logic [15:0]  m_axis_q_sym_o,
    output logic         lock_o,
    output logic         ted_err_valid_o,
    output logic [31:0]  ted_err_o,
    output logic [9:0]   mu_o,
    output logic [15:0]  w_o,
    input  logic         force_w_en_i,
    input  logic [15:0]  force_w_i
);

    // STR Clock Enable: ce_str = s_axis_valid_i | flush_active_i
    logic ce_str;
    assign ce_str = s_axis_valid_i | flush_active_i;

    // Parameters
    localparam int MU_WIDTH = 10;
    localparam int EMA_SHIFT = 4;
    localparam logic [31:0] LOCK_THR_ENTER = 32'h0000_C6FA; // 0.194313 in sQ4.18 (stored int 50938)
    localparam logic [31:0] LOCK_THR_EXIT  = 32'h0001_F172; // 0.485786 in sQ4.18 (stored int 127346)
    localparam int LOCK_CONFIRM_CNT = 20;

    // Signals
    logic [MU_WIDTH-1:0]  mu;
    logic                 mid_strobe, curr_strobe;
    logic                 mid_strobe_d, curr_strobe_d;

    logic signed [15:0]   i_y, q_y;
    logic                 y_valid;

    logic signed [15:0]   i_mid, q_mid;
    logic signed [15:0]   i_cur, q_cur;
    logic signed [15:0]   i_prev, q_prev;

    logic signed [31:0]   ted_error;
    logic                 ted_error_valid;

    logic signed [23:0]   pi_val;
    logic signed [15:0]   w_val, w_mux;

    // -------------------------------------------------------------------------
    // 1. Interpolators (4-cycle latency, sQ1.15 outputs)
    // -------------------------------------------------------------------------
    parabolic_farrow_interpolator #(
        .DATA_IN_INTEGER_WIDTH(1), .DATA_IN_FRACTIONAL_WIDTH(11),
        .DATA_OUT_INTEGER_WIDTH(1), .DATA_OUT_FRACTIONAL_WIDTH(15),
        .MU_WIDTH(MU_WIDTH)
    ) u_i_interp (
        .clk_i(clk_i), .rst_n_i(rst_ni), .valid_sample_i(ce_str),
        .x_i(s_axis_i_sample_i), .mu_i(mu), .y_o(i_y), .valid_sample_o()
    );

    parabolic_farrow_interpolator #(
        .DATA_IN_INTEGER_WIDTH(1), .DATA_IN_FRACTIONAL_WIDTH(11),
        .DATA_OUT_INTEGER_WIDTH(1), .DATA_OUT_FRACTIONAL_WIDTH(15),
        .MU_WIDTH(MU_WIDTH)
    ) u_q_interp (
        .clk_i(clk_i), .rst_n_i(rst_ni), .valid_sample_i(ce_str),
        .x_i(s_axis_q_sample_i), .mu_i(mu), .y_o(q_y), .valid_sample_o(y_valid)
    );

    // -------------------------------------------------------------------------
    // 2. Strobe Alignment Pipeline (3 shift stages = 4 cycles total latency)
    //    Cycle 0: sample x_i at input, modulo_1_controller calculates new_cur/mu
    //    Cycle 1: modulo_1_controller outputs registered current_strobe / mu;
    //             interpolator captures [s1, s2, s3, s4] = [t, t-1, t-2, t-3]
    //    Cycle 2: pipe[0] asserts; interpolator registers Stage 1 (v1, v2)
    //    Cycle 3: pipe[1] asserts; interpolator registers Stage 2 (h1)
    //    Cycle 4: pipe[2] asserts = curr_strobe_d; interpolator registers Stage 3 (y_o)
    //             m_axis_valid_o and m_axis_*_sym_o are valid at Cycle 4 (matching Golden Model)
    // -------------------------------------------------------------------------
    logic [3:0] mid_strobe_pipe, curr_strobe_pipe;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            mid_strobe_pipe  <= '0;
            curr_strobe_pipe <= '0;
        end else if (ce_str) begin
            mid_strobe_pipe  <= {mid_strobe_pipe[2:0], mid_strobe};
            curr_strobe_pipe <= {curr_strobe_pipe[2:0], curr_strobe};
        end else begin
            mid_strobe_pipe[3]  <= 1'b0;
            curr_strobe_pipe[3] <= 1'b0;
        end
    end

    assign mid_strobe_d   = mid_strobe_pipe[3];
    assign curr_strobe_d  = curr_strobe_pipe[3];

    assign m_axis_valid_o = curr_strobe_d;
    assign m_axis_i_sym_o = i_y;
    assign m_axis_q_sym_o = q_y;

    // Symbol data registers for Gardner TED
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            i_mid          <= '0; q_mid          <= '0;
            i_cur          <= '0; q_cur          <= '0;
            i_prev         <= '0; q_prev         <= '0;
        end else if (ce_str) begin
            if (mid_strobe_d) begin
                i_mid <= i_y;
                q_mid <= q_y;
            end

            if (curr_strobe_d) begin
                i_prev <= i_cur;
                q_prev <= q_cur;
                i_cur  <= i_y;
                q_cur  <= q_y;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Gardner TED
    // -------------------------------------------------------------------------
    gardner_ted_estimator u_ted (
        .clk_i(clk_i), .rst_ni(rst_ni), .ce_i(ce_str), .valid_i(curr_strobe_d),
        .i_mid_i(i_mid), .q_mid_i(q_mid),
        .i_cur_i(i_y), .q_cur_i(q_y),
        .i_prev_i(i_cur), .q_prev_i(q_cur),
        .error_o(ted_error), .error_valid_o(ted_error_valid)
    );

    assign ted_err_o       = ted_error;
    assign ted_err_valid_o = ted_error_valid;

    // -------------------------------------------------------------------------
    // 4. PI Loop Filter
    // -------------------------------------------------------------------------
    pI_loop u_pi_loop (
        .clk_i(clk_i), .rst_ni(rst_ni), .valid_i(ted_error_valid && ce_str),
        .error_i(ted_error), .pi_o(pi_val)
    );

    // -------------------------------------------------------------------------
    // 5. Modulo-1 Controller
    // -------------------------------------------------------------------------
    modulo_1_controller #(.MU_WIDTH(MU_WIDTH)) u_modulo_ctrl (
        .clk_i(clk_i), .rst_ni(rst_ni), .valid_sample_i(ce_str),
        .pi_i(pi_val), .mu_o(mu),
        .mid_strobe_o(mid_strobe), .current_strobe_o(curr_strobe),
        .w_o(w_val)
    );

    assign mu_o = mu;

    // Force W MUX (DFT feature)
    always_comb begin
        if (force_w_en_i) begin
            w_mux = force_w_i;
        end else begin
            w_mux = w_val;
        end
    end
    assign w_o = w_mux;

    // -------------------------------------------------------------------------
    // 6. Lock Detector (Synchronous Reset, reusing lock_detector.sv)
    //    Error: TED error (sQ3.21 in ted_error[24:0] sign-extended to 32 bits)
    //    Aligned to sQ4.18 by arithmetic right shift by 3 bits.
    //    Stored integer in 23-bit signed format (sQ4.18):
    //      Init_Error     = 23'd254691 (0.97157 in sQ4.18)
    //      LOCK_THR_ENTER = 23'd50938  (0.19431 in sQ4.18)
    //      LOCK_THR_EXIT  = 23'd127346 (0.48579 in sQ4.18)
    // -------------------------------------------------------------------------
    logic signed [22:0] ted_err_aligned;
    assign ted_err_aligned = ted_error[25:3];

    lock_detector #(
        .Error_Width   (23),
        .Alpha_Shift   (EMA_SHIFT),
        .Confirm_Count (LOCK_CONFIRM_CNT),
        .Min_Symbols   (1),
        .Init_Error    (23'd254691),
        .Pipelined     (1'b1)
    ) u_lock_detector (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .clr_i      (1'b0),
        .valid_i    (ted_error_valid && ce_str),
        .e_i        (ted_err_aligned),
        .thr_enter_i(23'd50938),
        .thr_exit_i (23'd127346),
        .lock_comb_o(),
        .locked_o   (lock_o)
    );

endmodule
