// Design Name:  Gardner Timing Error Detector (gardner_ted_estimator)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
//
// Calculates the timing error using the Gardner TED algorithm:
//   e = mid_I * (cur_I - prev_I) + mid_Q * (cur_Q - prev_Q)
// Inputs are signed 16-bit Q1.15 (sQ1.15).
// 2-Stage Pipelined Architecture (Latency = 2 clock cycles):
//   Stage 1: Register multiplier products i_mid * diff_I and q_mid * diff_Q
//   Stage 2: Register product sum, round to sQ3.21, and sign-extend to 32 bits
// Resets are purely synchronous (active-low rst_ni).

module gardner_ted_estimator #(
  parameter int DataWidth      = 16,
  parameter int DataFracBits   = DataWidth - 1,
  parameter int ErrActiveWidth = 25,
  parameter int ErrFracBits    = 21,
  parameter int ErrOutWidth    = 32
)(
  input  logic                        clk_i,
  input  logic                        rst_ni,        // Synchronous active-low reset
  input  logic                        ce_i,          // Clock enable (ce_str)
  input  logic                        valid_i,       // Current strobe strobe_d

  input  logic signed [DataWidth-1:0] i_mid_i,       // sQ1.(DataFracBits) mid-symbol sample
  input  logic signed [DataWidth-1:0] q_mid_i,       // sQ1.(DataFracBits) mid-symbol sample
  input  logic signed [DataWidth-1:0] i_cur_i,       // sQ1.(DataFracBits) current symbol sample (i_y)
  input  logic signed [DataWidth-1:0] q_cur_i,       // sQ1.(DataFracBits) current symbol sample (q_y)
  input  logic signed [DataWidth-1:0] i_prev_i,      // sQ1.(DataFracBits) previous symbol sample (i_cur register)
  input  logic signed [DataWidth-1:0] q_prev_i,      // sQ1.(DataFracBits) previous symbol sample (q_cur register)

  output logic signed [ErrOutWidth-1:0] error_o,     // Signed error output
  output logic                          error_valid_o // 1-cycle strobe when error_o updates (latency = 2)
);

  localparam int DiffWidth = DataWidth + 1;
  localparam int ProdWidth = DataWidth + DiffWidth;
  localparam int SumWidth  = ProdWidth + 1;
  localparam int ErrShift  = (2 * DataFracBits) - ErrFracBits;

  // -------------------------------------------------------------------------
  // Stage 1: Differences and Registered Multiplier Products (1 clock cycle)
  // -------------------------------------------------------------------------
  logic signed [DiffWidth-1:0] i_diff, q_diff;
  assign i_diff = i_cur_i - i_prev_i;
  assign q_diff = q_cur_i - q_prev_i;

  logic signed [ProdWidth-1:0] i_prod_q, q_prod_q;
  logic                        v_stg1_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      v_stg1_q <= 1'b0;
      i_prod_q <= '0;
      q_prod_q <= '0;
    end else if (ce_i) begin
      v_stg1_q <= valid_i;
      if (valid_i) begin
        i_prod_q <= i_mid_i * i_diff;
        q_prod_q <= q_mid_i * q_diff;
      end
    end
  end

  // -------------------------------------------------------------------------
  // Stage 2: Summation, Quantization, and Output Register (2 clocks)
  // -------------------------------------------------------------------------
  logic signed [SumWidth-1:0]       error_sum;
  logic signed [ErrActiveWidth-1:0] error_q21;

  assign error_sum = i_prod_q + q_prod_q;
  // Pure wire truncation matching MATLAB step_str.m
  assign error_q21 = ErrActiveWidth'(error_sum >>> ErrShift);

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      error_valid_o <= 1'b0;
      error_o       <= '0;
    end else if (ce_i) begin
      error_valid_o <= v_stg1_q;
      if (v_stg1_q) begin
        error_o <= ErrOutWidth'(error_q21);
      end
    end
  end

endmodule
