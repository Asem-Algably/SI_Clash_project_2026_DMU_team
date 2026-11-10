////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A complex multiplier module.
// Date: 6-11-2026
// Description: Multiply each number to its conjugate for the coarse CFO estimator.
////////////////////////////////////////////////////////////////////////////////

module complex_mult #(
  parameter int unsigned InWidth  = 16,  // Input sample width
  parameter int unsigned OutWidth = 32   // Output product width (32-bit is sufficient)
) (
  input  logic signed [InWidth-1:0]  a_re_i,  // Real part of A
  input  logic signed [InWidth-1:0]  a_im_i,  // Imag part of A
  input  logic signed [InWidth-1:0]  b_re_i,  // Real part of B
  input  logic signed [InWidth-1:0]  b_im_i,  // Imag part of B
  output logic signed [OutWidth-1:0] p_re_o,  // Real part of A*B
  output logic signed [OutWidth-1:0] p_im_o   // Imag part of A*B
);

  // Partial products, double width (32-bit)
  logic signed [2*InWidth-1:0] prod_rr;  // a_re * b_re
  logic signed [2*InWidth-1:0] prod_ii;  // a_im * b_im
  logic signed [2*InWidth-1:0] prod_ri;  // a_re * b_im
  logic signed [2*InWidth-1:0] prod_ir;  // a_im * b_re

  assign prod_rr = a_re_i * b_re_i;  // Real * Real
  assign prod_ii = a_im_i * b_im_i;  // Imag * Imag
  assign prod_ri = a_re_i * b_im_i;  // Real * Imag
  assign prod_ir = a_im_i * b_re_i;  // Imag * Real

  // (a_re + j*a_im) * (b_re + j*b_im) = (rr - ii) + j*(ri + ir)
  assign p_re_o = {{(OutWidth-2*InWidth){prod_rr[2*InWidth-1]}}, prod_rr} -
                  {{(OutWidth-2*InWidth){prod_ii[2*InWidth-1]}}, prod_ii};

  assign p_im_o = {{(OutWidth-2*InWidth){prod_ri[2*InWidth-1]}}, prod_ri} +
                  {{(OutWidth-2*InWidth){prod_ir[2*InWidth-1]}}, prod_ir};

endmodule 