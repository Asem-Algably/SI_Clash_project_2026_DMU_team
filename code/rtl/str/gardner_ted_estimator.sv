////////////////////////////////////////////////////////////////////////////////
// Author: Abd El-Rhman Khalifa
// Co_Author: Hadeer Ghoneim
// Design: Gardner Timing Error Detector (TED) module.
// Date: 12-11-2026
// Description: Calculates the timing error using the Gardner algorithm.
//              e = mid_I * (cur_I - prev_I) + mid_Q * (cur_Q - prev_Q)
////////////////////////////////////////////////////////////////////////////////

module gardner_ted_estimator (
  // ------------ control signals ------------
  input  logic               clk_i,      // System clock
  input  logic               rst_ni,     // Asynchronous active-low reset
  input  logic               valid_i,    // Valid input pulses

  // ------------ inputs ------------
  input  logic signed [15:0] i_mid_i,    // I-channel mid-symbol sample
  input  logic signed [15:0] q_mid_i,    // Q-channel mid-symbol sample
  input  logic signed [15:0] i_cur_i,    // I-channel current symbol sample
  input  logic signed [15:0] q_cur_i,    // Q-channel current symbol sample
  input  logic signed [15:0] i_prev_i,   // I-channel previous symbol sample
  input  logic signed [15:0] q_prev_i,   // Q-channel previous symbol sample

  // ------------ outputs ------------
  output logic signed [31:0] error_o,        // Calculated timing error
  output logic               error_valid_o   // Valid pulse for the output error
);

  // Internal signals for combinational calculations
  logic signed [16:0] i_diff, q_diff;    // 17-bit to hold the difference (prevents underflow)
  logic signed [32:0] i_prod, q_prod;    // 33-bit to hold the product of 16-bit * 17-bit
  logic signed [33:0] error_sum;         // 34-bit to hold the final sum (prevents overflow)

  // -------------------------------------------------------------------------
  // 1. Combinational Logic (Pure Math)
  // Calculates the error equation without any clock delay.
  // -------------------------------------------------------------------------
  always_comb begin
    // Calculate the difference between current and previous samples
    i_diff = i_cur_i - i_prev_i; 
    q_diff = q_cur_i - q_prev_i;
    
    // Multiply the mid-sample by the difference (Gardner algorithm)
    i_prod = i_mid_i * i_diff;
    q_prod = q_mid_i * q_diff;
    
    // Sum the I and Q branches to get the final error
    error_sum = i_prod + q_prod;
  end

  // -------------------------------------------------------------------------
  // 2. Sequential Logic (Pipeline for Timing Closure)
  // Delays the valid signal by 2 cycles to match the math latency.
  // Uses Non-Blocking Assignments (<=) to avoid race conditions.
  // -------------------------------------------------------------------------
  logic valid_q; // Register to hold the delayed valid signal

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q       <= '0; // Reset: clear valid flag
      error_o       <= '0; // Reset: clear output error
      error_valid_o <= '0; // Reset: clear output valid
    end else begin
      valid_q       <= valid_i;    // Delay valid_i by 1 cycle 
      error_valid_o <= valid_q;    // Delay valid_q by another cycle (Total 2 cycles delay)
      
      // Only capture the error_sum when the delayed valid signal is high
      // This prevents the output from updating when there's no new data.
      if (valid_q) begin
        error_o <= error_sum[31:0]; // Truncate 34-bit sum to 32-bit output
      end
    end
  end

endmodule
