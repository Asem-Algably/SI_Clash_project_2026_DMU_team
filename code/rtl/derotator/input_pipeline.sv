// Design Name:  Input latency alignment pipeline (input_pipeline)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// One register stage for the quadrant-rotated complex input symbol and its valid. It delays
// them by 1 clock, the read latency of the quarter-wave table (lut_rom), so that the symbol and
// the table values reach the multiplier in the same cycle.

module input_pipeline #(
    parameter int DataWidth = 16
)(
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         valid_i,
    input  logic signed [DataWidth-1:0]  xi_i,
    input  logic signed [DataWidth-1:0]  xq_i,

    output logic                         valid_o,
    output logic signed [DataWidth-1:0]  xi_o,
    output logic signed [DataWidth-1:0]  xq_o
);

    // Valid is reset, so no output is flagged valid after reset
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid_o <= 1'b0;
        end else begin
            valid_o <= valid_i;
        end
    end

    // The data registers have no reset and load only on valid_i. They are used only while
    // valid_o is high, and no reset lets Vivado place them in the DSP48 input registers.
    always_ff @(posedge clk_i) begin
        if (valid_i) begin
            xi_o   <= xi_i;
            xq_o   <= xq_i;
        end
    end

endmodule
