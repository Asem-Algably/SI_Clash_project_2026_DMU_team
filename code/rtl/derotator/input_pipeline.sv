/**
 * ============================================================================
 * Design Name:    Input Latency Alignment Pipeline (input_pipeline)
 * Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
 * Organization:   Electronics Research Institute (ERI) - CLASH Challenge
 * Author:         Haneen Fady Kamel Shahin
 * ============================================================================
 * Description:
 *   Pipeline registration stage for the (quadrant-rotated) complex input
 *   symbols. Delays the data by 1 clock cycle to match the read latency
 *   of the quarter-wave sine/cosine lookup table (lut_rom).
 * ============================================================================
 */
module input_pipeline #(
    parameter int W = 16
)(
    input  logic                 clk_i,
    input  logic                 rst_ni,
    input  logic                 valid_i,
    input  logic signed [W-1:0]  xi_i,
    input  logic signed [W-1:0]  xq_i,

    output logic                 valid_o,
    output logic signed [W-1:0]  xi_o,
    output logic signed [W-1:0]  xq_o
);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid_o <= 1'b0;
        end else begin
            valid_o <= valid_i;
        end
    end

    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            xi_o   <= xi_i;
            xq_o   <= xq_i;
        end
    end

endmodule