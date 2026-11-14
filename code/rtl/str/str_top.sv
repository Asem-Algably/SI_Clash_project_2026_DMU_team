module str_top (
    input  logic         clk_i,
    input  logic         rst_ni,
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
    localparam logic [31:0] LOCK_THR_ENTER = 32'h0010_0000;
    localparam logic [31:0] LOCK_THR_EXIT  = 32'h0020_0000;
    localparam int LOCK_CONFIRM_CNT = 16;

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
    
    logic signed [15:0]   pi_val;
    logic signed [15:0]   w_val, w_mux;


    // ------------ 1. Interpolators ------------
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


    // ------------ 2. Strobe Sampler ------------
    // Delay strobes by 5 cycles to match interpolator latency (shifts on ce_str)
    logic [4:0] mid_strobe_pipe, curr_strobe_pipe;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mid_strobe_pipe <= '0;
            curr_strobe_pipe <= '0;
        end else if (ce_str) begin
            mid_strobe_pipe <= {mid_strobe_pipe[3:0], mid_strobe};
            curr_strobe_pipe <= {curr_strobe_pipe[3:0], curr_strobe};
        end
    end

    assign mid_strobe_d = mid_strobe_pipe[4];
    assign curr_strobe_d = curr_strobe_pipe[4];

    // STR output valid: registered pulse cleared on any clock where ce_str = 0
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_axis_valid_o <= 1'b0;
        end else if (!ce_str) begin
            m_axis_valid_o <= 1'b0; // Exempt from freezing: cleared when ce_str = 0
        end else begin
            m_axis_valid_o <= curr_strobe_d;
        end
    end

    // Symbol data registers: freeze and hold their values when ce_str = 0
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            i_mid <= '0; q_mid <= '0;
            i_cur <= '0; q_cur <= '0;
            i_prev <= '0; q_prev <= '0;
            m_axis_i_sym_o <= '0;
            m_axis_q_sym_o <= '0;
        end else if (ce_str) begin
            if (mid_strobe_d) begin
                i_mid <= i_y;
                q_mid <= q_y;
            end
            
            if (curr_strobe_d) begin
                i_prev <= i_cur;
                q_prev <= q_cur;
                i_cur <= i_y;
                q_cur <= q_y;
                
                m_axis_i_sym_o <= i_y;
                m_axis_q_sym_o <= q_y;
            end
        end
    end

    // ------------ 3. Gardner TED ------------
    gardner_ted_estimator u_ted (
        .clk_i(clk_i), .rst_ni(rst_ni), .ce_i(ce_str), .valid_i(curr_strobe_d),
        .i_mid_i(i_mid), .q_mid_i(q_mid),
        .i_cur_i(i_cur), .q_cur_i(q_cur),
        .i_prev_i(i_prev), .q_prev_i(q_prev),
        .error_o(ted_error), .error_valid_o(ted_error_valid)
    );

    assign ted_err_o = ted_error;
    assign ted_err_valid_o = ted_error_valid;

    // ------------ 4. PI Loop Filter ------------
    pI_loop u_pi_loop (
        .clk_i(clk_i), .rst_ni(rst_ni), .valid_i(ted_error_valid && ce_str),
        .error_i(ted_error), .pi_o(pi_val)
    );

    // ------------ 5. Modulo-1 Controller ------------
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

    // ------------ 6. Lock Detector ------------
    logic [31:0] abs_error;
    logic [31:0] ema_q;
    logic [15:0] leaky_bucket;
    
    always_comb begin
        abs_error = ted_error[31] ? -ted_error : ted_error;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ema_q <= '0;
        end else if (ted_error_valid && ce_str) begin
            ema_q <= ema_q + ((abs_error - ema_q) >>> EMA_SHIFT);
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            leaky_bucket <= '0;
        end else if (ted_error_valid && ce_str) begin
            if (!lock_o && (ema_q < LOCK_THR_ENTER)) begin
                if (leaky_bucket < LOCK_CONFIRM_CNT) leaky_bucket <= leaky_bucket + 1;
            end else if (lock_o && (ema_q > LOCK_THR_EXIT)) begin
                if (leaky_bucket > 0) leaky_bucket <= leaky_bucket - 2;
            end
        end
    end

    assign lock_o = (leaky_bucket >= LOCK_CONFIRM_CNT);

endmodule