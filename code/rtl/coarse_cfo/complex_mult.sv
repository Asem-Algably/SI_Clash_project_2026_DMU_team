////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A complex multiplier module.
// Date: 6-11-2026
// Description: Multiply each number to its conjugate for the coarse CFO estimator.
////////////////////////////////////////////////////////////////////////////////

module complex_mult #(
  parameter int unsigned InWidth  = 16,  // Input sample width
  parameter int unsigned OutWidth = 33   // Output product width (fixed_point mult_out 33-bit)
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
  
  // Real Part Calculation: (Real * Real) - (Imag * Imag)
  // To prevent overflow during subtraction, both 32-bit products are 
  // sign-extended to 33 bits (OutWidth) BEFORE the subtraction.
  // 33-(2*16) = 1 : Sign Extend from product by replicating its MSB to the sign bit
  // sign bit merged with the product output which has width of (2*16)-1 = 31
  // one more bit for overflow

endmodule 
