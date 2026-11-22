// Design Name:  Derotator top level (derotator)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// Rotates each symbol by minus the NCO phase: y = x * exp(-j * theta). Structural top level of
// the frequency word register, NCO, quarter-wave sine/cosine ROM, quadrant rotator, input
// pipeline and complex multiplier (see derotator.md).
//
// Data path:
//   - theta is a 32-bit binary radian (2^32 = one turn, pi/2 = 2^30). The top two bits are
//     the quadrant q, the next Phase_Bits bits are the table index a.
//   - The quadrant is applied to the INPUT symbol, x' = x * (-j)^q, so the multiplier always
//     uses the q = 0 equations with the 0..90 degree table values c0 and s0.
//   - No combinational logic sits between the registers (ROM output, input_pipeline) and the
//     DSP48 multiplier inputs.
//
// Latency, s_axis_valid_i to m_axis_valid_o: 3 clock cycles.
//   1 (ROM read, and the registered rotated symbol) + 2 (multiplier: products, then
//   add/round/saturate).
// A new freq_adj_i reaches the NCO one cycle later, through the freq_word_o register.
//
// DFT: force_freq_en_i overrides the frequency word with force_freq_i.

module derotator #(
    parameter int Width = 32,
    parameter int Phase_Bits = 12,
    parameter int DataWidth =16,
    parameter int Frac = DataWidth - 1,
    parameter int Coarse_W = 24,
    parameter int Coarse_Shift = Width - Coarse_W
)(
    input logic                         clk_i,
    input logic                         rst_ni,

    // Symbol input from the STR, valid strobe only (no ready)
    input logic                         s_axis_valid_i,
    input logic signed [DataWidth-1:0]  s_axis_i_sym_i,
    input logic signed [DataWidth-1:0]  s_axis_q_sym_i,

    // Coarse frequency word, one pulse from the coarse CFO estimator (2^24 = one turn)
    input logic                         coarse_valid_i,
    input logic signed [Coarse_W-1:0]   coarse_word_i,

    // Frequency correction from the Costas PI filter (2^32 = one turn)
    input logic                         freq_adj_valid_i,
    input logic signed [Width-1:0]      freq_adj_i,

    // DFT override of the frequency word
    input logic                         force_freq_en_i,
    input logic        [Width-1:0]      force_freq_i,

    // Initial phase correction k * pi/2, one pulse from the Costas loop
    input logic                         phase_adj_valid_i,
    input logic        [Width-1:0]      phase_adj_i,

    // Derotated symbol output
    output logic                          m_axis_valid_o,
    output logic signed [DataWidth-1:0]   m_axis_i_sym_o,
    output logic signed [DataWidth-1:0]   m_axis_q_sym_o,

    // Observation: NCO phase and frequency word (DFT mux)
    output logic        [Width-1:0]       phase_o,
    output logic        [Width-1:0]       freq_word_o

);
    // Internal connecting wires
    logic        [1:0]            quad;       // quadrant q, from the NCO phase
    logic        [Phase_Bits-1:0] lut_idx;    // table index a, from the NCO phase
    logic signed [DataWidth-1:0]  s0, c0;     // ROM outputs: sine, cosine of the 0..90 degree angle
    logic signed [DataWidth-1:0]  xi_rot, xq_rot;  // input symbol after x * (-j)^q
    logic                         valid_d1;   // input valid, delayed by 1 clock
    logic signed [DataWidth-1:0]  xi_d1, xq_d1;    // rotated symbol, aligned with c0 and s0

    // Frequency word: coarse word plus Costas correction, with the DFT override
    freq_word #(
        .Width(Width),
        .Coarse_W(Coarse_W),
        .Coarse_Shift(Coarse_Shift)
    ) freq_word_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .freq_adj_i(freq_adj_i),
        .freq_adj_valid_i(freq_adj_valid_i),
        .force_freq_en_i(force_freq_en_i),
        .force_freq_i(force_freq_i),
        .coarse_word_i(coarse_word_i),
        .coarse_valid_i(coarse_valid_i),
        .freq_word_o(freq_word_o)
    );

    // NCO phase accumulator: adds the frequency word on every valid symbol and the one-time
    // phase correction on its rising edge
    NCO_accumulator #(
        .Acc_W(Width),
        .Phase_Bits(Phase_Bits)
    ) nco_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .s_axis_valid_i(s_axis_valid_i),
        .fcw_i(freq_word_o),
        .phase_adj_valid_i(phase_adj_valid_i),
        .phase_adj_i(phase_adj_i),
        .phase_o(phase_o),
        .quad_o(quad),
        .lut_idx_o(lut_idx)
    );

    // Quarter-wave ROM: s0 = S[a], c0 = S[~a] (complementary address), 1 clock read latency
    lut_rom #(
        .DataWidth(DataWidth),
        .Phase_Bits(Phase_Bits)
    ) lut_rom_inst (
        .clk_i(clk_i),
        .s_axis_valid_i(s_axis_valid_i),
        .a_i(lut_idx),
        .cos_o(c0),
        .sin_o(s0)
    );

    // Quadrant rotation of the input symbol, x' = x * (-j)^q (combinational).
    // quad is the NCO register output in the same cycle as the table address and the symbol.
    quadrant_rotator #(
        .DataWidth(DataWidth)
    ) quadrant_rotator_inst (
        .quad_i(quad),
        .xi_i(s_axis_i_sym_i),
        .xq_i(s_axis_q_sym_i),
        .xi_o(xi_rot),
        .xq_o(xq_rot)
    );

    // Input pipeline: registers the rotated symbol and the valid for 1 clock, the same as the
    // ROM read latency
    input_pipeline #(
        .DataWidth(DataWidth)
    ) input_pipeline_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .valid_i(s_axis_valid_i),
        .xi_i(xi_rot),
        .xq_i(xq_rot),
        .valid_o(valid_d1),
        .xi_o(xi_d1),
        .xq_o(xq_d1)
    );

    // Complex multiplier with the q = 0 equations: y = x' * (c0 - j * s0)
    complex_multiplier #(
        .DataWidth(DataWidth),
        .Frac(Frac)
    ) complex_multiplier_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .s_axis_valid_i(valid_d1),
        .s_axis_i_sym_i(xi_d1),
        .s_axis_q_sym_i(xq_d1),
        .cos_th(c0),      // c0, the ROM output register, no logic in between
        .sin_th(s0),      // s0, the ROM output register, no logic in between
        .m_axis_i_sym_o(m_axis_i_sym_o),
        .m_axis_q_sym_o(m_axis_q_sym_o),
        .m_axis_valid_o(m_axis_valid_o)
    );

endmodule
