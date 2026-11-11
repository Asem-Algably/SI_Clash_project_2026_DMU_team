////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: An accumulator module.
// Date: 6-11-2026
// Description: Delay line and accumulator for Coarse CFO estimator.
////////////////////////////////////////////////////////////////////////////////

module accumulator #(
  parameter int unsigned InWidth  = 33,  // Complex sample width
  parameter int unsigned AccWidth = 40,  // Accumulator width
  parameter int unsigned WinLen   = 32   // Window length in symbols
) (
  input  logic                       clk_i,     // Clock
  input  logic                       rst_ni,    // Async reset, active low
  input  logic                       start_i,   // Burst start
  input  logic                       valid_i,   // Symbol valid
  input  logic signed [InWidth-1:0]  in_re_i,   // Real sample in
  input  logic signed [InWidth-1:0]  in_im_i,   // Imag sample in
  output logic signed [AccWidth-1:0] out_re_o,  // Real sum out
  output logic signed [AccWidth-1:0] out_im_o,  // Imag sum out
  output logic                       valid_o    // Level: window is done
);

  // Parameterized counter width to 5 registers
  localparam int unsigned CountWidth = $clog2(WinLen);

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
    end else if (valid_i && (count_q < WinLen - 1)) begin
      out_re_o <= out_re_o + in_re_i;   // Accumulate real part
      out_im_o <= out_im_o + in_im_i;   // Accumulate imag part
      count_q  <= count_q + 1'b1;       // Advance counter
    end
  end

  // Valid is edge-detect for single pulse.
  assign valid_o = (count_q == WinLen - 1);

endmodule 