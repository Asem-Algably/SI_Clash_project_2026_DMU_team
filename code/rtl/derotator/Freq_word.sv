// Design Name:  Frequency word register (freq_word)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// Forms the NCO frequency word: freq_word_o = coarse + correction, registered (1 clock).
//   - coarse_word_i is signed 24 bit, 2^24 = one turn per symbol. It is loaded into coarse_reg
//     on coarse_valid_i and scaled by 2^Coarse_Shift (a left shift by 8) to the 32-bit NCO
//     units, where 2^32 = one turn per symbol. A new coarse word is used in the same cycle it
//     is loaded.
//   - freq_adj_i is the signed 32-bit correction of the Costas PI filter, in the same units.
//     The last valid correction is held in adj_reg and used until the next freq_adj_valid_i.
//   - force_freq_en_i overrides the result with force_freq_i (DFT).
// All registers reset to 0, so the word is 0 before the coarse word arrives.

module freq_word #(
    parameter int Width = 32,
    parameter int Coarse_W = 24,
    parameter int Coarse_Shift = Width - Coarse_W
)(
    input logic                        clk_i,
    input logic                        rst_ni,

    // Coarse frequency word from the coarse CFO estimator: signed, 2^Coarse_W = one turn
    input logic signed  [Coarse_W-1:0] coarse_word_i,
    // One pulse: load coarse_word_i
    input logic                        coarse_valid_i,

    // Correction from the Costas PI filter: signed, 2^Width = one turn
    input logic signed  [Width-1:0]    freq_adj_i,
    // Take freq_adj_i as the new held correction
    input logic                        freq_adj_valid_i,

    // DFT: when force_freq_en_i is high, force_freq_i replaces the frequency word
    input logic                        force_freq_en_i,
    input logic         [Width-1:0]    force_freq_i,

    // Frequency control word for the NCO accumulator
    output logic signed [Width-1:0]    freq_word_o
);

    logic signed [Width-1:0] coarse_reg;
    logic signed [Width-1:0] coarse_ext;    // coarse word scaled to NCO units (x 2^Coarse_Shift)
    logic signed [Width-1:0] coarse_now;    // coarse word in effect now (bypasses coarse_reg)
    logic signed [Width-1:0] active_freq;   // coarse word plus correction, before the register
    logic signed [Width-1:0] freq_adj_used; // newest correction: the input when valid, else adj_reg

    // Scale the coarse word to NCO units by appending Coarse_Shift zero LSBs. The sign is kept.
    assign coarse_ext = {coarse_word_i, {Coarse_Shift{1'b0}}};

    // Last valid correction from the Costas loop, held until the next freq_adj_valid_i
    logic signed [Width-1:0] adj_reg;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)               adj_reg <= '0;
        else if (freq_adj_valid_i) adj_reg <= freq_adj_i;
    end

    // Coarse word register, loaded on coarse_valid_i with the scaled value (see coarse_ext)
    always_ff @(posedge clk_i or negedge rst_ni)begin
        if(!rst_ni)begin
            coarse_reg <= '0;
        end
        else if (coarse_valid_i) begin
            coarse_reg <= coarse_ext;
        end
    end

    // Use a new coarse word and a new correction in the same cycle they arrive, without waiting
    // for the registers
    always_comb begin
        coarse_now  = coarse_valid_i ? coarse_ext : coarse_reg;
        freq_adj_used = freq_adj_valid_i ? freq_adj_i : adj_reg;
        active_freq = coarse_now + freq_adj_used;
    end

    // Output register with the DFT override: force_freq_en_i has priority over the normal path
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            freq_word_o <= '0;
        end else if (force_freq_en_i) begin
            freq_word_o <= force_freq_i; // DFT / Test override
        end else begin
            freq_word_o <= active_freq;  // Normal operational path
        end
    end

endmodule
