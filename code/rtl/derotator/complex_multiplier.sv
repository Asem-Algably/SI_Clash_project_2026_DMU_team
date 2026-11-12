// Design Name:  Complex multiplier, derotator mixer (complex_multiplier)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// 2-stage pipelined complex multiplier of the derotator. It multiplies the quadrant-rotated
// symbol x' by (c0 - j * s0), where c0 and s0 are the cosine and sine of the 0..90 degree
// angle from the ROM. The quadrant has already been applied to the symbol, so the equations
// are those of q = 0:
//   y_re = x'_re * c0 + x'_im * s0
//   y_im = x'_im * c0 - x'_re * s0
//
// Format: Q1.(DataWidth-1) in and out (default DataWidth = 16, Q1.15).
// Latency: 2 clocks.
//   Stage 1: the four products, full precision, for the DSP48 blocks.
//   Stage 2: add or subtract, round half up (toward +infinity, once, after the sum), then
//            saturate to the Q1.15 range.

module complex_multiplier #(
    parameter int DataWidth    = 16,     // data and table width, Q1.(DataWidth-1)
    parameter int Frac = DataWidth - 1   // fraction bits of the inputs, shift after the products
)(
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                s_axis_valid_i,         // input valid (symbol strobe)

    // Quadrant-rotated symbol x'
    input  logic signed [DataWidth-1:0] s_axis_i_sym_i,
    input  logic signed [DataWidth-1:0] s_axis_q_sym_i,
    // Table values: cosine c0 and sine s0 of the 0..90 degree angle, not of the full NCO phase
    input  logic signed [DataWidth-1:0] cos_th,
    input  logic signed [DataWidth-1:0] sin_th,

    output logic signed [DataWidth-1:0] m_axis_i_sym_o,
    output logic signed [DataWidth-1:0] m_axis_q_sym_o,
    output logic                        m_axis_valid_o
);
    localparam int PW = 2*DataWidth;                       // product width
    localparam int SW = PW + 1;                    // sum width (for rounding)
    localparam logic signed [SW-1:0] RND = SW'(1) <<< (Frac-1);  // half an LSB of the output
    localparam logic signed [DataWidth-1:0]  MAXV =  {1'b0, {(DataWidth-1){1'b1}}};
    localparam logic signed [DataWidth-1:0]  MINV =  {1'b1, {(DataWidth-1){1'b0}}};

    logic signed [PW-1:0] i_cos, q_sin, q_cos, i_sin;
    logic                 valid;

    // Valid strobe pipeline, 2 clocks, aligned with the data stages below
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid        <= 1'b0;
            m_axis_valid_o <= 1'b0;
        end else begin
            valid        <= s_axis_valid_i;
            m_axis_valid_o <= valid;
        end
    end

    // Stage 1: products. No reset on the datapath, so Vivado can pack them into DSP48 blocks.
    always_ff @(posedge clk_i) begin
        if (s_axis_valid_i) begin
            i_cos <= s_axis_i_sym_i * cos_th;
            q_sin <= s_axis_q_sym_i * sin_th;
            q_cos <= s_axis_q_sym_i * cos_th;
            i_sin <= s_axis_i_sym_i * sin_th;
        end
    end

    // Stage 2 helper: round half up (add half an LSB, then shift right by Frac) and saturate
    function automatic logic signed [DataWidth-1:0] rnd_sat(input logic signed [SW-1:0] v);
        logic signed [SW-1:0] r;
        r = (v + RND) >>> Frac;
        if      (r > SW'(MAXV)) return MAXV;
        else if (r < SW'(MINV)) return MINV;
        else                    return r[DataWidth-1:0]; // in range: keep the lower DataWidth bits
    endfunction

    // Stage 2: combine the products, then round and saturate
    always_ff @(posedge clk_i) begin
        if (valid) begin
            m_axis_i_sym_o <= rnd_sat(SW'(i_cos) + SW'(q_sin));
            m_axis_q_sym_o <= rnd_sat(SW'(q_cos) - SW'(i_sin));
        end
    end
endmodule
