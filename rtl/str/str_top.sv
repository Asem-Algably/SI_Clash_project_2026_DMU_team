// Design Name:  Symbol Timing Recovery Top (str_top)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
//
// Structural top level of the STR subsystem:
//   1. Parabolic Farrow Interpolators (I and Q branches, 6 cycles latency, sQ1.15)
//   2. 6-Cycle Total Strobe Alignment Pipeline
//   3. Gardner Timing Error Detector (sQ3.21)
//   4. Proportional-Integral (PI) Loop Filter
//   5. Modulo-1 NCO Controller
//   6. STR Lock Detector
//
// Output symbols are signed 16-bit Q1.15 (sQ1.15).
// Resets are purely synchronous (active-low rst_ni).

module str_top #(
    parameter int                           InSampleIntWidth   = 1,
    parameter int                           InSampleFracWidth  = 11,
    parameter int                           OutSymIntWidth     = 1,
    parameter int                           OutSymFracWidth    = 15,
    parameter int                           GainWidth          = 8,
    parameter int                           TedErrActiveWidth  = 25,
    parameter int                           TedErrFracBits     = 21,
    parameter int                           TedErrWidth        = 32,
    parameter int                           MuWidth            = 10,
    parameter int                           NcoWidth           = 24,
    parameter int                           PiGainWidth        = 24,
    parameter int                           KpFracBits         = 25,
    parameter int                           KiFracBits         = 31,
    parameter int                           PiIntWidth         = 26,
    parameter int                           PiIntFracBits      = 28,
    parameter int                           PiOutFracBits      = 24,
    parameter logic [PiGainWidth-1:0]       KP                 = 24'h0A_EDD7,
    parameter logic [PiGainWidth-1:0]       KI                 = 24'h09_53F9,
    parameter logic signed [PiIntWidth-1:0] MAX_V_PI           = 26'sh08F_5C29,
    parameter int                           ForceWWidth        = 16,
    parameter int                           StrAlignLatency    = 4,
    parameter int                           EmaShift           = 4,
    parameter int                           LockErrWidth       = 23,
    parameter int                           LockErrLsb         = 3,
    parameter int                           LockConfirmCnt     = 20,
    parameter int                           LockMinSymbols     = 1,
    parameter logic [LockErrWidth-1:0]      LockInitError      = 23'd254691,
    parameter logic [LockErrWidth-1:0]      LockThrEnter       = 23'd50938,
    parameter logic [LockErrWidth-1:0]      LockThrExit        = 23'd127346,
    parameter bit                           LockPipelined      = 1'b1
)(
    input  logic                                                      clk_i,
    input  logic                                                      rst_ni,             // Synchronous active-low reset
    input  logic                                                      s_axis_valid_i,
    input  logic                                                      flush_active_i,
    input  logic [InSampleIntWidth+InSampleFracWidth-1:0]             s_axis_i_sample_i,
    input  logic [InSampleIntWidth+InSampleFracWidth-1:0]             s_axis_q_sample_i,
    input  logic [GainWidth-1:0]                                      loop_gain_i,
    output logic                                                      m_axis_valid_o,
    output logic [OutSymIntWidth+OutSymFracWidth-1:0]                 m_axis_i_sym_o,
    output logic [OutSymIntWidth+OutSymFracWidth-1:0]                 m_axis_q_sym_o,
    output logic                                                      lock_o,
    output logic                                                      ted_err_valid_o,
    output logic [TedErrWidth-1:0]                                    ted_err_o,
    output logic [MuWidth-1:0]                                        mu_o,
    output logic [ForceWWidth-1:0]                                    w_o,
    input  logic                                                      force_w_en_i,
    input  logic [ForceWWidth-1:0]                                    force_w_i
);

    localparam int InSampleWidth = InSampleIntWidth + InSampleFracWidth;
    localparam int OutSymWidth   = OutSymIntWidth + OutSymFracWidth;

    // STR Clock Enable: ce_str = s_axis_valid_i | flush_active_i
    logic ce_str;
    assign ce_str = s_axis_valid_i | flush_active_i;

    // Signals
    logic [MuWidth-1:0]   mu, mu_d;
    logic                 mid_strobe, curr_strobe;
    logic                 mid_strobe_d, curr_strobe_d;

    logic signed [OutSymWidth-1:0]   i_y, q_y;
    logic                            y_valid;

    logic signed [OutSymWidth-1:0]   i_mid, q_mid;
    logic signed [OutSymWidth-1:0]   i_cur, q_cur;
    logic signed [OutSymWidth-1:0]   i_prev, q_prev;

    logic signed [TedErrWidth-1:0]   ted_error;
    logic                            ted_error_valid;

    logic signed [NcoWidth-1:0]      pi_val;
    logic signed [ForceWWidth-1:0]   w_val, w_mux;

    // -------------------------------------------------------------------------
    // 1. Interpolators (4-cycle latency, sQ(OutSymIntWidth).(OutSymFracWidth))
    // -------------------------------------------------------------------------
    parabolic_farrow_interpolator #(
        .DATA_IN_INTEGER_WIDTH   (InSampleIntWidth),
        .DATA_IN_FRACTIONAL_WIDTH(InSampleFracWidth),
        .DATA_OUT_INTEGER_WIDTH  (OutSymIntWidth),
        .DATA_OUT_FRACTIONAL_WIDTH(OutSymFracWidth),
        .MU_WIDTH                (MuWidth)
    ) u_i_interp (
        .clk_i(clk_i), .rst_n_i(rst_ni), .valid_sample_i(ce_str),
        .x_i(s_axis_i_sample_i), .mu_i(mu_d), .y_o(i_y), .valid_sample_o()
    );

    parabolic_farrow_interpolator #(
        .DATA_IN_INTEGER_WIDTH   (InSampleIntWidth),
        .DATA_IN_FRACTIONAL_WIDTH(InSampleFracWidth),
        .DATA_OUT_INTEGER_WIDTH  (OutSymIntWidth),
        .DATA_OUT_FRACTIONAL_WIDTH(OutSymFracWidth),
        .MU_WIDTH                (MuWidth)
    ) u_q_interp (
        .clk_i(clk_i), .rst_n_i(rst_ni), .valid_sample_i(ce_str),
        .x_i(s_axis_q_sample_i), .mu_i(mu_d), .y_o(q_y), .valid_sample_o(y_valid)
    );

    // -------------------------------------------------------------------------
    // 2. Strobe Alignment Pipeline (6 cycles total latency = 3 modulo stages + 3 interpolator stages)
    // -------------------------------------------------------------------------
    logic [StrAlignLatency-1:0] mid_strobe_pipe, curr_strobe_pipe;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            mid_strobe_pipe  <= '0;
            curr_strobe_pipe <= '0;
            mu_d             <= '0;
        end else if (ce_str) begin
            mid_strobe_pipe  <= {mid_strobe_pipe[StrAlignLatency-2:0], mid_strobe};
            curr_strobe_pipe <= {curr_strobe_pipe[StrAlignLatency-2:0], curr_strobe};
            // Delay mu by 1 ce_str cycle to stay aligned with Farrow's 7-tap window [s7..s4] on adjacent strobes
            mu_d             <= mu;
        end else begin
            mid_strobe_pipe[StrAlignLatency-1]  <= 1'b0;
            curr_strobe_pipe[StrAlignLatency-1] <= 1'b0;
        end
    end

    assign mid_strobe_d   = mid_strobe_pipe[StrAlignLatency-1];
    assign curr_strobe_d  = curr_strobe_pipe[StrAlignLatency-1];

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
    gardner_ted_estimator #(
        .DataWidth     (OutSymWidth),
        .DataFracBits  (OutSymFracWidth),
        .ErrActiveWidth(TedErrActiveWidth),
        .ErrFracBits   (TedErrFracBits),
        .ErrOutWidth   (TedErrWidth)
    ) u_ted (
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
    pI_loop #(
        .ErrInWidth    (TedErrWidth),
        .ErrActiveWidth(TedErrActiveWidth),
        .ErrFracBits   (TedErrFracBits),
        .GainWidth     (PiGainWidth),
        .KpFracBits    (KpFracBits),
        .KiFracBits    (KiFracBits),
        .PiIntWidth    (PiIntWidth),
        .PiIntFracBits (PiIntFracBits),
        .PiOutWidth    (NcoWidth),
        .PiOutFracBits (PiOutFracBits),
        .KP            (KP),
        .KI            (KI),
        .MAX_V_PI      (MAX_V_PI)
    ) u_pi_loop (
        .clk_i(clk_i), .rst_ni(rst_ni), .valid_i(ted_error_valid && ce_str),
        .error_i(ted_error), .pi_o(pi_val)
    );

    // -------------------------------------------------------------------------
    // 5. Modulo-1 Controller
    // -------------------------------------------------------------------------
    modulo_1_controller #(
        .MU_WIDTH   (MuWidth),
        .NCO_WIDTH  (NcoWidth),
        .PI_WIDTH   (NcoWidth),
        .W_OUT_WIDTH(ForceWWidth)
    ) u_modulo_ctrl (
        .clk_i(clk_i), .rst_ni(rst_ni), .valid_sample_i(ce_str),
        .pi_i(pi_val), .force_w_en_i(force_w_en_i), .force_w_i(force_w_i),
        .mu_o(mu), .mid_strobe_o(mid_strobe), .current_strobe_o(curr_strobe),
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
    // -------------------------------------------------------------------------
    logic signed [LockErrWidth-1:0] ted_err_aligned;
    assign ted_err_aligned = ted_error[LockErrLsb +: LockErrWidth];

    lock_detector #(
        .Error_Width   (LockErrWidth),
        .Alpha_Shift   (EmaShift),
        .Confirm_Count (LockConfirmCnt),
        .Min_Symbols   (LockMinSymbols),
        .Init_Error    (LockInitError),
        .Pipelined     (LockPipelined)
    ) u_lock_detector (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .clr_i      (1'b0),
        .valid_i    (ted_error_valid && ce_str),
        .e_i        (ted_err_aligned),
        .thr_enter_i(LockThrEnter),
        .thr_exit_i (LockThrExit),
        .lock_comb_o(),
        .locked_o   (lock_o)
    );

endmodule
