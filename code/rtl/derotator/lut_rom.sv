/**
 * ============================================================================
 * Design Name:    Quarter-Wave Sine/Cosine Lookup Table (LUT ROM)
 * Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
 * Organization:   Electronics Research Institute (ERI) - CLASH Challenge
 * Author:         Haneen Fady Kamel Shahin
 * ============================================================================
 * Description:
 *   Synchronous, Block-RAM (BRAM) based lookup table storing a 1/4 cycle sine
 *   wave in fixed-point Q1.15 format. Utilizes bit-inversion (~a_i) 
 *   addressing for cosine generation to exploit quarter-wave symmetry.
 *   Sequential reads are gated by the symbol valid strobe (s_axis_valid_i).
 * 
 * Specifications:
 *   - Phase Resolution: Configurable index width (default 12 bits = 4096 entries)
 *   - Output Precision: 16-bit signed Q1.15 format
 *   - Memory Mapping: Block RAM inferred via (* rom_style = "block" *)
 * ============================================================================
 */

module lut_rom #(
    parameter int    PHASE_BITS = 12,                      // a = theta[29 : 30-PHASE_BITS]
    parameter int    W          = 16                       // Q1.15 output
)(
    input  logic                    clk_i,
    input  logic                    s_axis_valid_i,       // read enable = symbol valid
    input  logic [PHASE_BITS-1:0]   a_i,      // in-quadrant table index
    output logic signed [W-1:0]      cos_o,
    output logic signed [W-1:0]      sin_o
);
    localparam int MEM_DEPTH = 1 << PHASE_BITS; // 2**PHASE_BITS here, 4096 for PHASE_BITS=12

    (* rom_style = "block" *) logic [W-1:0] mem [MEM_DEPTH];

    initial $readmemh("sine_quarter_lut.dat", mem);

    // Sequential BRAM read gated by the symbol valid strobe
    // Read the LUT on the rising edge of clk_i when s_axis_valid_i is high.
    // The LUT is a quarter-wave sine table, so the cosine is read from the mirrored address (2**PHASE_BITS - 1 - a_i).
    always_ff @(posedge clk_i) begin
        if (s_axis_valid_i) begin
            sin_o <= $signed(mem[a_i]);
            cos_o <= $signed(mem[~a_i]);
        end
    end
endmodule
