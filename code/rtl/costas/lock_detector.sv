// ============================================================================
// File Name   : lock_detector.sv
// Module Name : lock_detector
// Author      : Arwa Kantoush
// Description : Costas loop lock detector using leaky-bucket EMA algorithm.
//               3-stage pipeline architecture with hysteresis thresholding.
// ============================================================================
module lock_detector #(
    parameter int                       Error_Width   = 16,
    parameter int                       Alpha_Shift   = 4,
    parameter int                       Confirm_Count = 8,
    parameter int                       Min_Symbols   = 15,
    parameter logic [Error_Width-1:0]   Init_Error    = 16'd8192 // Initial bad value (0.25 in Q1.15)
)(
    input  logic                           clk_i,
    input  logic                           rst_ni,
    input  logic                           clr_i,
    input  logic                           valid_i,
    input  logic signed [Error_Width-1:0]  e_i,
    input  logic        [Error_Width-1:0]  thr_enter_i,
    input  logic        [Error_Width-1:0]  thr_exit_i,

    output logic                           locked_o
);
    localparam int AW = Error_Width + Alpha_Shift;
    localparam int BW = $clog2(Confirm_Count + 1);
    localparam int CW = $clog2(Min_Symbols + 1);

    // ---------------------------------------------------- stage 1: |e|
    logic [Error_Width-1:0]e_abs_r;
    logic v1;

    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            e_abs_r <= e_i[Error_Width-1] ? Error_Width'(~e_i + 1'b1) : Error_Width'(e_i);
        end
    end

    // ---------------------------------------------------- stage 2: EMA update
    logic [AW-1:0]          m_acc, m_next;
    logic [Error_Width-1:0] m_val_r;
    logic [CW-1:0]          sym_cnt;
    logic                   idx_ok_r;
    logic                   v2;

    always_comb begin
        m_next = m_acc + AW'(e_abs_r) - (m_acc >> Alpha_Shift);   // m += |e| - m/2^Alpha_Shift
    end

    always_ff @(posedge clk_i) begin
        if (v1) begin
            m_val_r  <= m_next[AW-1:Alpha_Shift];                 // updated EMA, compared in stage 3
            idx_ok_r <= (sym_cnt >= CW'(Min_Symbols - 1));        // sym_idx >= Min_Symbols
        end
    end

    // ---------------------------------------------------- stage 3: compare + bucket + lock
    logic [Error_Width-1:0] thr;
    logic [BW-1:0]          bucket, bucket_next;
    logic                   good;

    always_comb begin
        thr  = locked_o ? thr_exit_i : thr_enter_i;     // hysteresis
        good = (m_val_r < thr) && idx_ok_r;

        if (good) begin
            bucket_next = (bucket >= BW'(Confirm_Count)) ? bucket : bucket + 1'b1; // min(b+1, Confirm_Count)
        end
        else if (bucket >= BW'(2)) begin
            bucket_next = bucket - BW'(2);              // max(b-2, 0)
        end
        else begin
            bucket_next = '0;
        end
    end

    // ---------------------------------------------------- control / state
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            v1       <= 1'b0;
            v2       <= 1'b0;
            m_acc    <= AW'(Init_Error) << Alpha_Shift;
            sym_cnt  <= '0;
            bucket   <= '0;
            locked_o <= 1'b0;
        end
        else if (clr_i) begin
            v1       <= 1'b0;
            v2       <= 1'b0;
            m_acc    <= AW'(Init_Error) << Alpha_Shift;
            sym_cnt  <= '0;
            bucket   <= '0;
            locked_o <= 1'b0;
        end
        else begin
            v1 <= valid_i;
            v2 <= v1;

            if (v1) begin
                m_acc <= m_next;
                if (sym_cnt != CW'(Min_Symbols)) begin
                    sym_cnt <= sym_cnt + 1'b1;
                end
            end

            if (v2) begin
                bucket <= bucket_next;
                if (bucket_next >= BW'(Confirm_Count)) begin
                    locked_o <= 1'b1;
                end
                else if (bucket_next == '0) begin
                    locked_o <= 1'b0;
                end
            end
        end
    end
endmodule
