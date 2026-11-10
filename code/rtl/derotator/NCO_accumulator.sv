/**
 * ============================================================================
 * Design Name:    Numerically Controlled Oscillator (NCO) / Phase Accumulator
 * Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
 * Organization:   Electronics Research Institute (ERI) - CLASH Challenge
 * Author:         Haneen Fady Kamel Shahin
 * ============================================================================
 * Description:
 *   32-bit binary-radian NCO accumulator designed for the Costas loop derotator. 
 *   Accumulates the frequency control word (Fcw_i) and initial phase adjustments 
 *   on every valid symbol strobe. Outputs the full phase accumulator value, 
 *   quadrant select bits (top 2 bits), and quarter-wave table index bits.
 * 
 * Specifications:
 *   - Accumulator Width: 32 bits (2^32 = one full turn, pi/2 = 2^30)[cite: 3]
 *   - Phase Resolution: Configurable phase bits (default 12 bits)
 * ============================================================================
 */

module NCO_accumulator #(
    parameter int ACCW = 32,
    parameter int PHASE_BITS = 12
)(
    input logic clk_i,
    input logic rst_ni,
    input logic s_axis_valid_i,                        // when the input symbol is valid, the NCO will update the phase accumulator
    input logic [ACCW-1:0] Fcw_i,                       //output freq_word_o from freq_word module
    input logic phase_adj_valid_i,                   //when the phase_adj_i is valid, the phase_o will be updated 
    input logic [ACCW-1:0] phase_adj_i,             //phase correction from the Costas loop

    output logic [ACCW-1:0] phase_o,               //phase accumulator output
    output logic [1:0]          quad_o, 
    output logic [PHASE_BITS-1:0]    lut_idx_o
);

    logic [ACCW-1:0] inc;
    assign inc = (s_axis_valid_i ? Fcw_i : '0) + (phase_adj_valid_i ? phase_adj_i : '0);

    // The phase accumulator is updated on the rising edge of clk_i when either s_axis_valid_i or phase_adj_valid_i is high. The increment value (inc) is the sum of the frequency control word and any valid phase adjustment. If neither input is valid, the increment is zero, and the accumulator holds its value.
    always_ff @(posedge clk_i or negedge rst_ni)begin
        if (!rst_ni)begin
         phase_o <= '0;
        end
        else begin
            phase_o <= phase_o + inc;
        end
    end
    //two outputs will be used in lut_rom module to get the sin and cos values

    assign quad_o    = phase_o[ACCW-1 -: 2];          //last 2 bits of phase_o determine the quadrant
    assign lut_idx_o = phase_o[ACCW-3 -: PHASE_BITS]; //from bit 29 to bit 30-PHASE_BITS determine the index of the LUT
    
endmodule