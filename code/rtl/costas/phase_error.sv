// ============================================================================
// File Name   : phase_error.sv
// Module Name : phase_error
// Author      : Arwa Kantoush
// Description : Phase error detector (Im{y * a*}) in Q1.15 format.
//               3-stage pipeline: multiply / subtract / round+shift+saturate.
// ============================================================================
module phase_error #(
    parameter int Data_Width     = 16,
    parameter int Error_Width    = 16,
    parameter int Data_Frac_Bits = 15
)(
    input  logic                          clk_i,
    input  logic                          rst_ni,
    input  logic        [1:0]             mode_i,
    input  logic                          valid_i,
    input  logic signed [Data_Width-1:0]  yi_i, yq_i,
    input  logic signed [Data_Width-1:0]  ai_i, aq_i,

    output logic signed [Error_Width-1:0] e_o,
    output logic                          valid_o
);
    localparam logic        [1:0]             MODE_HOLD = 2'b00;
    localparam logic signed [2*Data_Width:0]  HALF      = 1 <<< (Data_Frac_Bits-1);
    localparam logic signed [Error_Width-1:0] E_MAX     = {1'b0, {(Error_Width-1){1'b1}}};
    localparam logic signed [Error_Width-1:0] E_MIN     = {1'b1, {(Error_Width-1){1'b0}}};

    logic signed [2*Data_Width-1:0] m_qa, m_ia;     // stage 1: yq*ai, yi*aq
    logic signed [2*Data_Width:0]   diff_r;         // stage 2: m_qa - m_ia
    logic signed [2*Data_Width:0]   shifted;
    logic signed [Error_Width-1:0]  e_next;
    logic                           v_m, v_d;

    //---------------------------------------------------- stage 1: multiply (no reset, absorbed into the DSP)
    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            m_qa <= yq_i * ai_i;
            m_ia <= yi_i * aq_i;
        end
    end

    //---------------------------------------------------- stage 2: subtract
    always_ff @(posedge clk_i) begin
        if (v_m) begin
            diff_r <= (2*Data_Width+1)'(m_qa) - (2*Data_Width+1)'(m_ia);
        end
    end

    //---------------------------------------------------- stage 3: round + shift + saturate
    always_comb begin
        shifted = (diff_r + HALF) >>> Data_Frac_Bits;
        e_next  = shifted[Error_Width-1:0];
        if (shifted > $signed(E_MAX)) begin
            e_next = E_MAX;
        end
        else if (shifted < $signed(E_MIN)) begin
            e_next = E_MIN;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            v_m     <= 1'b0;
            v_d     <= 1'b0;
            e_o     <= '0;
            valid_o <= 1'b0;
        end
        else if (mode_i == MODE_HOLD) begin
            v_m     <= 1'b0;
            v_d     <= 1'b0;
            e_o     <= '0;
            valid_o <= 1'b0;
        end
        else begin
            v_m     <= valid_i;
            v_d     <= v_m;
            valid_o <= v_d;
            if (v_d) begin
                e_o <= e_next;
            end
        end
    end

endmodule
