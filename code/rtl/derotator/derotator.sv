/**
 * ============================================================================
 * Design Name:    Derotator Top-Level Subsystem (derotator)
 * Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
 * Organization:   Electronics Research Institute (ERI) - CLASH Challenge
 * Author:         Haneen Fady Kamel Shahin
 * ============================================================================
 * Description:
 *   Structural top-level container integrating the frequency control word 
 *   generator, NCO, quarter-wave LUT ROM, input pipeline alignment, quadrant 
 *   rotator, and pipelined complex multiplier for carrier phase/frequency recovery.
 *
 *   Sample-path latency (s_axis_valid_i -> m_axis_valid_o): 3 clock cycles
 *     1 (LUT read, and the registered quadrant-rotated input) + 2 (complex
 *     multiplier: products, add/round/sat).
 *
 *   Full-circle rotation: the quadrant sign/swap is applied to the INPUT symbol
 *   (x' = x * (-j)^q) before the input_pipeline register, so the multiplier
 *   always uses the q = 0 equations with c0/s0 straight from the 0..90 degree LUT.
 *   Neither the LUT output nor the rotator logic sits in front of the DSP48 inputs.
 *   A new freq_adj_i additionally takes 1 cycle to reach the NCO (freq_word_o register).
 * ============================================================================
 */
module derotator #(
    parameter int WIDTH = 32,
    parameter int PHASE_BITS = 12,
    parameter int W =16,
    parameter int FRAC = W - 1,
    parameter int COARSE_W = 24,
    parameter int COARSE_SHIFT = WIDTH - COARSE_W
)(
    input logic                 clk_i,
    input logic                 rst_ni,
    input logic                 s_axis_valid_i,
    input logic signed [15:0]   s_axis_i_sym_i,
    input logic signed [15:0]   s_axis_q_sym_i,
    input logic                 coarse_valid_i,
    input logic [COARSE_W-1:0]  coarse_word_i,
    input logic                 freq_adj_valid_i,
    input logic signed [31:0]   freq_adj_i,
    input logic                 phase_adj_valid_i,
    input logic [WIDTH-1:0]     phase_adj_i,
    /*
    //TBD
    input logic                 force_freq_en_i,
    input logic signed [WIDTH-1:0] force_freq_i,
    //
    */
    output logic                 m_axis_valid_o,
    output logic signed [15:0]   m_axis_i_sym_o,
    output logic signed [15:0]   m_axis_q_sym_o,
    output logic [WIDTH-1:0]     phase_o,
    output logic [WIDTH-1:0]     freq_word_o

);
    // Internal connecting wires
    logic [1:0]          quad;
    logic [PHASE_BITS-1:0] lut_idx;
    logic signed [W-1:0] s0, c0;                 // LUT outputs (0..90 degrees)
    logic signed [W-1:0] xi_rot, xq_rot;         // input symbol after x * (-j)^q
    logic                valid_d1;
    logic signed [W-1:0] xi_d1, xq_d1;           // registered, aligned with c0/s0

    //...............freq_word module instantiation..............
    freq_word #(
        .WIDTH(WIDTH),
        .COARSE_W(COARSE_W),
        .COARSE_SHIFT(COARSE_SHIFT)
    ) freq_word_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .freq_adj_i(freq_adj_i),
        .freq_adj_valid_i(freq_adj_valid_i),
        .coarse_word_i(coarse_word_i),
        .coarse_valid_i(coarse_valid_i),
        .freq_word_o(freq_word_o)
    );

    //..................NCO Instantiation...........................
    NCO_accumulator #(
        .ACCW(WIDTH),
        .PHASE_BITS(PHASE_BITS)
    ) nco_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .s_axis_valid_i(s_axis_valid_i),
        .Fcw_i(freq_word_o),
        .phase_adj_valid_i(phase_adj_valid_i),
        .phase_adj_i(phase_adj_i),
        .phase_o(phase_o),
        .quad_o(quad),
        .lut_idx_o(lut_idx)
    );

    //...................Quarter-Wave Sine/Cosine ROM Instantiation..................
    lut_rom #(
        .W(W),
        .PHASE_BITS(PHASE_BITS)
    ) lut_rom_inst (
        .clk_i(clk_i),
        .s_axis_valid_i(s_axis_valid_i),
        .a_i(lut_idx),
        .cos_o(c0),
        .sin_o(s0)
    );

    //...............Quadrant rotation of the input: x' = x * (-j)^q (combinational)...............
    // quad comes from the NCO register in the same cycle as the LUT address and the input symbol.
    quadrant_rotator #(
        .W(W)
    ) quadrant_rotator_inst (
        .quad_i(quad),
        .xi_i(s_axis_i_sym_i),
        .xq_i(s_axis_q_sym_i),
        .xi_o(xi_rot),
        .xq_o(xq_rot)
    );

    //...............Input Pipeline / Latency Alignment (1 clock = LUT read latency)...............
    input_pipeline #(
        .W(W)
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

    //...............Complex Multiplier / Derotator Mixer (q = 0 equations)...............
    complex_multiplier #(
        .W(W),
        .FRAC(FRAC)
    ) complex_multiplier_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .s_axis_valid_i(valid_d1),
        .s_axis_i_sym_i(xi_d1),
        .s_axis_q_sym_i(xq_d1),
        .cos_th(c0),      // straight from the ROM
        .sin_th(s0),      // straight from the ROM
        .m_axis_i_sym_o(m_axis_i_sym_o),
        .m_axis_q_sym_o(m_axis_q_sym_o),
        .m_axis_valid_o(m_axis_valid_o)
    );

endmodule