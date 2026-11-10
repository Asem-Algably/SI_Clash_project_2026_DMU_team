/**
 * ============================================================================
 * Design Name:    Frequency Word Generator & Register (freq_word)
 * Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
 * Organization:   Electronics Research Institute (ERI) - CLASH Challenge
 * Author:         Haneen Fady Kamel Shahin
 * ============================================================================
 * Description:
 *   Combines the scaled coarse frequency word with signed loop filter 
 *   frequency corrections (`freq_adj_i`) from the Costas loop. Generates 
 *   the active 32-bit frequency control word (`freq_word_o`) supplied to 
 *   the NCO accumulator.
 * 
 * Specifications:
 *   - Accumulator/Output Width: 32 bits (2^32 = one turn per symbol)
 *   - Coarse Input Width: 24 bits, signed, 2^24 = one turn per symbol
 *     (scaled by 2^COARSE_SHIFT, i.e. left-shifted by 8, to NCO units)
 *   - Correction Input: Signed 32-bit frequency adjustment
 * ============================================================================
 */

module freq_word #(
    parameter int WIDTH = 32,
    parameter int COARSE_W = 24,
    parameter int COARSE_SHIFT = WIDTH - COARSE_W
)(
    input logic clk_i,
    input logic rst_ni,

    input logic [COARSE_W-1:0] coarse_word_i,       // 24-bit coarse frequency word from the coarse frequency generator
    input logic coarse_valid_i,                    // Indicates when the coarse frequency word is valid and should be loaded

    input logic signed [WIDTH-1:0]freq_adj_i,     //output of pi loop filter (corrected freq)
    input logic freq_adj_valid_i,                //when the freq_adj_i is valid, the freq_word_o will be updated

    output logic [WIDTH-1:0] freq_word_o        //32-bit frequency control word to the NCO accumulator
);
    
    logic [WIDTH-1:0] coarse_reg;
    logic [WIDTH-1:0] coarse_ext;    // coarse word scaled to NCO units (x 2^COARSE_SHIFT)
    logic [WIDTH-1:0] coarse_now;    // coarse word in effect this cycle (bypasses the register on load)
    logic [WIDTH-1:0] active_freq;

    // 32-bit value with 2^32 = 1 turn by appending COARSE_SHIFT zero LSBs (sign is preserved).
    assign coarse_ext = {coarse_word_i, {COARSE_SHIFT{1'b0}}};

    // Loads the coarse word, scaled to NCO units (see coarse_ext).

    always_ff @(posedge clk_i or negedge rst_ni)begin
        if(!rst_ni)begin
            coarse_reg <= '0;
        end
        else if (coarse_valid_i) begin
            coarse_reg <= coarse_ext;
        end
    end
    
    // The active frequency word is the sum of the coarse frequency word and the fine frequency adjustment from the loop filter. This allows for dynamic frequency adjustments while maintaining a base frequency set by the coarse word.
    // FIX 2: bypass the register when a new coarse word arrives, so the new value is used in the same cycle.
    always_comb begin
        coarse_now  = coarse_valid_i ? coarse_ext : coarse_reg;
        active_freq = coarse_now + freq_adj_i;
    end

    //output pipelining
    always_ff @(posedge clk_i or negedge rst_ni)begin
        if(!rst_ni)begin
            freq_word_o <= '0;
        end
        else if (coarse_valid_i || freq_adj_valid_i) begin
            freq_word_o <= active_freq;
        end
    end

endmodule

 
//incase of DFT override, the freq_word_o will be updated with the force_freq_i when force_freq_en_i is high
/*
//additional inputs
// DFT / Override inputs
    input logic                    force_freq_en_i,
    input logic [WIDTH-1:0]        force_freq_i,
//Output selection with DFT override MUX
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            freq_word_o <= '0;
        end else if (force_freq_en_i) begin
            freq_word_o <= force_freq_i; // DFT / Test override
        end else begin
            freq_word_o <= active_freq;  // Normal operational path
        end
    end
*/