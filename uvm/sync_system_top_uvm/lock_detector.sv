// ============================================================================
// File Name   : lock_detector.sv
// Module Name : lock_detector
// Author      : Arwa Kantoush
// Description : Costas loop lock detector using leaky-bucket EMA algorithm.
//               Single-cycle EMA update aligned with golden model step_costas_ld.
// ============================================================================
module lock_detector #(
    parameter int                       Error_Width   = 16,
    parameter int                       Alpha_Shift   = 4,
    parameter int                       Confirm_Count = 8,
    parameter int                       Min_Symbols   = 15,
    parameter logic [Error_Width-1:0]   Init_Error    = 16'd8192, // Initial bad value (0.25 in Q1.15)
    parameter bit                       Pipelined     = 1'b0
)(
    input  logic                           clk_i,
    input  logic                           rst_ni,
    input  logic                           clr_i,
    input  logic                           valid_i,
    input  logic signed [Error_Width-1:0]  e_i,
    input  logic        [Error_Width-1:0]  thr_enter_i,
    input  logic        [Error_Width-1:0]  thr_exit_i,

    output logic                           locked_o,
    output logic                           lock_comb_o
);
    localparam int AW = Error_Width + Alpha_Shift;
    localparam int BW = $clog2(Confirm_Count + 1);
    localparam int CW = (Min_Symbols > 0) ? $clog2(Min_Symbols + 1) : 1;

    generate
    if (Pipelined) begin : gen_pipelined
        // -----------------------------------------------------------------
        // 3-stage pipeline architecture (used by STR, matching step_str.m)
        // -----------------------------------------------------------------
        logic [Error_Width-1:0] e_abs_r;
        logic                   v1, v2;
        logic [AW-1:0]          m_acc, m_next;
        logic [Error_Width-1:0] m_val_r;
        logic [CW-1:0]          sym_cnt;
        logic                   idx_ok_r;
        logic [Error_Width-1:0] thr;
        logic [BW-1:0]          bucket, bucket_next;
        logic                   good;
        logic                   locked_q;

        always_ff @(posedge clk_i) begin
            if (!rst_ni || clr_i) begin
                e_abs_r <= '0;
            end else if (valid_i) begin
                e_abs_r <= e_i[Error_Width-1] ? Error_Width'(~e_i + 1'b1) : Error_Width'(e_i);
            end
        end

        assign m_next = m_acc + AW'(e_abs_r) - (m_acc >> Alpha_Shift);

        always_ff @(posedge clk_i) begin
            if (!rst_ni || clr_i) begin
                m_val_r  <= Init_Error;
                idx_ok_r <= 1'b0;
            end else if (v1) begin
                m_val_r  <= m_next[AW-1:Alpha_Shift];
                idx_ok_r <= (Min_Symbols == 0) || (sym_cnt >= CW'(Min_Symbols - 1));
            end
        end

        assign thr  = locked_q ? thr_exit_i : thr_enter_i;
        assign good = (m_val_r < thr) && idx_ok_r;

        always_comb begin
            if (good) begin
                bucket_next = (bucket >= BW'(Confirm_Count)) ? bucket : bucket + 1'b1;
            end else if (bucket >= BW'(2)) begin
                bucket_next = bucket - BW'(2);
            end else begin
                bucket_next = '0;
            end
        end

        always_ff @(posedge clk_i) begin
            if (!rst_ni || clr_i) begin
                v1       <= 1'b0;
                v2       <= 1'b0;
                m_acc    <= AW'(Init_Error) << Alpha_Shift;
                sym_cnt  <= '0;
                bucket   <= '0;
                locked_q <= 1'b0;
            end else begin
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
                        locked_q <= 1'b1;
                    end else if (bucket_next == '0) begin
                        locked_q <= 1'b0;
                    end
                end
            end
        end

        assign locked_o    = locked_q;
        assign lock_comb_o = locked_q;

    end else begin : gen_single_cycle
        // -----------------------------------------------------------------
        // Single-cycle EMA architecture (used by Costas, matching step_costas.m)
        // -----------------------------------------------------------------
        logic [Error_Width-1:0] e_abs;
        logic [AW-1:0]          m_acc, m_next;
        logic [Error_Width-1:0] m_val;
        logic [CW-1:0]          sym_cnt;
        logic                   idx_ok;
        logic [Error_Width-1:0] thr;
        logic [BW-1:0]          bucket, bucket_next;
        logic                   good;
        logic                   locked_q, locked_comb;

        assign e_abs  = e_i[Error_Width-1] ? Error_Width'(~e_i + 1'b1) : Error_Width'(e_i);
        assign m_next = m_acc + AW'(e_abs) - (m_acc >> Alpha_Shift);
        assign m_val  = m_next[AW-1:Alpha_Shift];

        assign idx_ok = (Min_Symbols == 0) || (sym_cnt >= CW'(Min_Symbols - 1));
        assign thr    = locked_q ? thr_exit_i : thr_enter_i;
        assign good   = (m_val < thr) && idx_ok;

        always_comb begin
            if (good) begin
                bucket_next = (bucket >= BW'(Confirm_Count)) ? bucket : bucket + 1'b1;
            end else if (bucket >= BW'(2)) begin
                bucket_next = bucket - BW'(2);
            end else begin
                bucket_next = '0;
            end
        end

        assign locked_comb = (bucket_next >= BW'(Confirm_Count)) ? 1'b1 :
                             (bucket_next == '0) ? 1'b0 : locked_q;

        assign locked_o    = locked_q;
        assign lock_comb_o = valid_i ? locked_comb : locked_q;

        always_ff @(posedge clk_i) begin
            if (!rst_ni || clr_i) begin
                m_acc    <= AW'(Init_Error) << Alpha_Shift;
                sym_cnt  <= '0;
                bucket   <= '0;
                locked_q <= 1'b0;
            end else if (valid_i) begin
                m_acc    <= m_next;
                bucket   <= bucket_next;
                locked_q <= locked_comb;
                if (sym_cnt != CW'(Min_Symbols)) begin
                    sym_cnt <= sym_cnt + 1'b1;
                end
            end
        end
    end
    endgenerate
endmodule
