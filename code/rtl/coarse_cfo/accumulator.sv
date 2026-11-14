////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         An accumulator module.
// Date:           6-11-2026
// Description:    Delay line and accumulator for Coarse CFO estimator.
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

module accumulator #(
  
  parameter int unsigned InWidth  = 33,  // Complex sample input width ( is the complex multiplier output width)
  
  parameter int unsigned AccWidth = 40,  // Accumulator width
  //33 bit width input + 5 bit for 32 (2^5) window lengh = 38 bits 
  //if used 6 bit for 64 (2^6) window lengh + 33 bit width input = 39
  // and one or two more bits for fixed point addition overflow = 40 total
  
  parameter int unsigned WinLen   = 32,  // Window length in symbols (number of symbols to sum)
  parameter int unsigned Lag      = 4    // Delay line priming lag (symbols to skip)
) (
  input  logic                       clk_i,     // Clock
  input  logic                       rst_ni,    // Async reset, active low
  input  logic                       start_i,   // Burst start
  input  logic                       valid_i,   // Symbol valid
  input  logic signed [InWidth-1:0]  in_re_i,   // Real sample in
  input  logic signed [InWidth-1:0]  in_im_i,   // Imag sample in
  output logic signed [AccWidth-1:0] out_re_o,  // Real sum out
  output logic signed [AccWidth-1:0] out_im_o,  // Imag sum out
  output logic                       valid_o    // valid output pulse
);

  localparam int unsigned CountWidth = $clog2(WinLen + 1);

  // Registered flip flops to store the current symbol count and track the accumulation window.
  logic [CountWidth-1:0] count_q;  // Symbols accumulated so far

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      out_re_o <= '0;                   // Reset sum
      out_im_o <= '0;                   // Reset sum
      count_q  <= '0;                   // Reset counter
    end else if (!start_i) begin
      out_re_o <= '0;                   // Clear at burst end
      out_im_o <= '0;                   // Clear at burst end
      count_q  <= '0;                   // Clear counter
    end else if (valid_i && (count_q < WinLen)) begin
      if (count_q >= Lag) begin
        out_re_o <= out_re_o + in_re_i; // Accumulate real part once delay line is primed
        out_im_o <= out_im_o + in_im_i; // Accumulate imag part once delay line is primed
      end
      count_q  <= count_q + 1'b1;       // Advance counter
    end
  end

  assign valid_o = (count_q == WinLen);
  // Valid is edge-detect for single pulse.
  // Flag to indicate the accumulation window is complete.
  // Hardware counts from 0, so the final (32nd) sample is at index 31 (WinLen - 1).
  // the final sample will be received when the counter reaches its MAXIMUM value: (WinLen - 1).
  // When this condition is true, valid_o asserts high (Level) to indicate the window is full.

endmodule 
