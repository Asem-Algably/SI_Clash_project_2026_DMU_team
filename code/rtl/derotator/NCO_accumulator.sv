// Design Name:  NCO phase accumulator (NCO_accumulator)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// 32-bit binary radian NCO phase accumulator of the derotator (2^32 = one turn, pi/2 = 2^30,
// R.120). It wraps naturally at 2^32.
//   - On every valid symbol (s_axis_valid_i) the frequency control word is added:
//     phase_o <= phase_o + fcw_i. The quadrant and table index of a symbol come from phase_o
//     as it is before that symbol's increment.
//   - The initial phase correction phase_adj_i is added once, on the rising edge of
//     phase_adj_valid_i, also in the same cycle as a valid symbol. A valid held high adds the
//     correction only once; it must go low between two corrections.
//   - Outputs: the full phase, the quadrant (top two bits) and the quarter-wave table index
//     (the next Phase_Bits bits).

module NCO_accumulator #(
    parameter int Acc_W = 32,
    parameter int Phase_Bits = 12
)(
    input logic                    clk_i,
    input logic                    rst_ni,
    // Valid symbol: accumulate the frequency control word
    input logic                    s_axis_valid_i,
    // Frequency control word, the freq_word_o of freq_word
    input logic  [Acc_W-1:0]       fcw_i,
    // Initial phase correction valid, its rising edge is used
    input logic                    phase_adj_valid_i,
    // Initial phase correction k * pi/2, from the Costas loop
    input logic  [Acc_W-1:0]       phase_adj_i,

    // Phase accumulator, 2^Acc_W = one turn
    output logic [Acc_W-1:0]       phase_o,
    // Quadrant, phase_o[31:30]
    output logic [1:0]             quad_o,
    // Quarter-wave table index, phase_o[29 : 30-Phase_Bits], for lut_rom
    output logic [Phase_Bits-1:0]  lut_idx_o
);

    logic [Acc_W-1:0] inc;
    logic phase_adj_valid_q;
    logic phase_adj_pulse;

    // Delay phase_adj_valid_i by one clock, for the rising-edge detect below
    always_ff @(posedge clk_i or negedge rst_ni)begin
        if(!rst_ni)begin
            phase_adj_valid_q <= 0;
        end
        else begin
            phase_adj_valid_q <= phase_adj_valid_i;
        end
    end

    // One pulse per rising edge of phase_adj_valid_i, so a held valid adds the correction once
    assign phase_adj_pulse = phase_adj_valid_i & ~ phase_adj_valid_q;

    // Increment: the frequency word on a valid symbol plus the phase correction on its pulse.
    // It is 0 when neither is active, and the accumulator then holds its value.
    assign inc = (s_axis_valid_i ? fcw_i : '0) + (phase_adj_pulse ? phase_adj_i : '0);

    // Phase accumulator, updated every clock. The carry out is dropped on purpose: the phase
    // wraps at 2^Acc_W, which is one full turn.
    always_ff @(posedge clk_i or negedge rst_ni)begin
        if (!rst_ni)begin
         phase_o <= '0;
        end
        else begin
            phase_o <= phase_o + inc;
        end
    end

    // The two outputs below address lut_rom for the sine and cosine values
    // Quadrant: the two most significant bits of the phase
    assign quad_o    = phase_o[Acc_W-1 -: 2];
    // Table index: bits [29 : 30-Phase_Bits] of the phase. The lower bits are dropped (truncation).
    assign lut_idx_o = phase_o[Acc_W-3 -: Phase_Bits];

endmodule
