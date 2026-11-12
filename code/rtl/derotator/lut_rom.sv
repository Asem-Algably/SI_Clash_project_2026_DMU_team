// Design Name:  Quarter-wave sine/cosine lookup table (lut_rom)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// Synchronous quarter-wave sine table in Q1.15. The read is gated by the symbol valid strobe
// (s_axis_valid_i) and takes 1 clock.
//   - sin_o = S[a_i], with S[a] = sin((a + 0.5) * (pi/2) / 4096) scaled to Q1.15 (midpoint
//     sampling, the maximum entry is 0x7FFF).
//   - cos_o = S[~a_i]. The complementary address gives the cosine exactly, because midpoint
//     sampling makes S[4095 - a] = cos((a + 0.5) * (pi/2) / 4096).
//   - Entries must be in 0 .. 0x7FFF: 0x8000 would read as -1.0 and flip the sign.
//
// One description for both flows: the table is a constant case statement in
// sine_quarter_lut.svh, generated from the MATLAB table. There is no initial block, no
// $readmemh and no file at run time.
//   - FPGA: Vivado infers a ROM from the case statement with a registered read and maps it to
//           block RAM (rom_style attribute).
//   - ASIC: synthesizes to a constant logic table.

module lut_rom #(
    // Index width: a = theta[29 : 30-Phase_Bits]. The content is generated for 12.
    parameter int Phase_Bits = 12,
    // Output width, Q1.15. The content is generated for 16.
    parameter int DataWidth  = 16
)(
    input  logic                          clk_i,
    // Read enable: the symbol valid
    input  logic                          s_axis_valid_i,
    // In-quadrant table index
    input  logic        [Phase_Bits-1:0]  a_i,
    output logic signed [DataWidth-1:0]   cos_o,
    output logic signed [DataWidth-1:0]   sin_o
);
    // The table content is generated for 12 index bits and 16-bit entries only
    if (Phase_Bits != 12 || DataWidth != 16) begin : g_check
        $error("sine_quarter_lut.svh is generated for Phase_Bits = 12 and DataWidth = 16");
    end

    // Constant table: sine of the in-quadrant angle, midpoint sampled. One case item per entry.
    function automatic logic [DataWidth-1:0] rom_f(input logic [Phase_Bits-1:0] a);
        logic [DataWidth-1:0] v;
        v = '0;
        case (a)
            `include "sine_quarter_lut.svh"
            default: v = '0;
        endcase
        return v;
    endfunction

    // Registered outputs. The attribute maps these registers and the table to block RAM in
    // Vivado, and is ignored by ASIC tools.
    (* rom_style = "block" *) logic [DataWidth-1:0] sin_q;
    (* rom_style = "block" *) logic [DataWidth-1:0] cos_q;

    // Read on the rising edge of clk_i when s_axis_valid_i is high, and hold otherwise.
    // The cosine comes from the mirrored address (2**Phase_Bits - 1 - a_i) = ~a_i.
    always_ff @(posedge clk_i) begin
        if (s_axis_valid_i) begin
            sin_q <= rom_f(a_i);
            cos_q <= rom_f(~a_i);
        end
    end

    assign sin_o = $signed(sin_q);
    assign cos_o = $signed(cos_q);
endmodule
