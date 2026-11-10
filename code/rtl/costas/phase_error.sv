// ============================================================================
// File Name   : phase_error.sv
// Module Name : phase_error
// Author      : Arwa Kantoush
// Description : Phase error detector (Im{y * a*}) in Q1.15 format.
//               Features a 2-stage pipeline to achieve 125MHz timing closure.
// ============================================================================
module phase_error #(
    parameter int W = 16,
    parameter int EW = 16,
    parameter int FRAC = 15
)(
    input logic clk_i,
    input logic rst_ni,
    input logic [1:0]mode_i,
    input logic valid_i,
    input logic signed [W-1:0]yi_i, yq_i,
    input logic signed [W-1:0]ai_i, aq_i,
    output logic signed [EW-1:0]e_o,
    output logic valid_o
);
    localparam logic [1:0]MODE_HOLD = 2'b00;
    localparam logic signed [2*W:0]HALF = 1 <<< (FRAC-1);// 0.5 in Q1.15 format
    localparam logic signed [EW-1:0]E_MAX = {1'b0, {(EW-1){1'b1}}};// 0.999969482421875 in Q1.15 format
    localparam logic signed [EW-1:0]E_MIN = {1'b1, {(EW-1){1'b0}}};// -1.0 in Q1.15 format

    logic signed [2*W:0]diff, shifted;
    logic signed [EW-1:0]e_next;
    logic signed [2*W-1:0]m_qa, m_ia;     // yq*ai, yi*aq
    logic v_m;

    //---------------------------------------------------- stage 1: m_qa = yq*ai, m_ia = yi*aq
    always_ff @(posedge clk_i) begin      // no reset: absorbed into the DSP
        if (valid_i) begin
            m_qa <= yq_i * ai_i;  
            m_ia <= yi_i * aq_i;
        end
    end

    //---------------------------------------------------- stage 2: e = (m_qa - m_ia) >> FRAC
    always_comb begin
        diff = (2*W+1)'(m_qa) - (2*W+1)'(m_ia);
        shifted = (diff + HALF) >>> FRAC;
        e_next = shifted[EW-1:0];
        if (shifted > $signed(E_MAX)) begin
            e_next = E_MAX;
        end
        else if (shifted < $signed(E_MIN)) begin
            e_next = E_MIN;
        end
    end

    //---------------------------------------------------- stage 3: output register
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            v_m <= 1'b0;
            e_o <= '0;
            valid_o <= 1'b0;
        end
        else if (mode_i == MODE_HOLD) begin
            v_m <= 1'b0;
            e_o <= '0;
            valid_o <= 1'b0;
        end
        else begin
            v_m <= valid_i;
            valid_o <= v_m;
            if (v_m) begin
                e_o <= e_next;
            end
        end
    end

endmodule
