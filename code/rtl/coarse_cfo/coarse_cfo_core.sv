////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         A coarse_cfo_core module.
// Date:           9-11-2026
// Description:    Coarse CFO estimator, lag D = 4, window 32 symbols.
//                 Computes R = sum(r[n] * conj(r[n-4])), then angle(R) >> 2.
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

module coarse_cfo_core #(
  parameter int unsigned DataWidth = 16,  // Input sample width
  parameter int unsigned Lag       = 4,   // Delay in symbols
  parameter int unsigned WinLen    = 32,  // Symbols per window
  parameter int unsigned AccWidth  = 40   // Accumulator width
) (
  input  logic                       clk_i,           // Clock
  input  logic                       rst_ni,          // Async reset, active low
  input  logic                       start_i,         // Start a new window
  input  logic                       s_axis_valid_i,  // Symbol strobe
  input  logic signed [DataWidth-1:0] s_axis_i_sym_i, // I symbol in
  input  logic signed [DataWidth-1:0] s_axis_q_sym_i, // Q symbol in
  output logic                       m_axis_valid_o,  // One-pulse estimate ready
  output logic signed [23:0]         m_axis_cfo_o,    // Estimate out
  input  logic                       force_cfo_en_i,  // Force override enable
  input  logic [23:0]                force_cfo_i      // Forced value (DFT)
);

  // Parameterized counter width to 5 registers
  localparam int unsigned SymCountWidth = $clog2(WinLen + 1);

  // Symbol counter for the window
  logic [SymCountWidth-1:0] sym_count_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sym_count_q <= '0;                     // Reset counter
    end else if (!start_i) begin
      sym_count_q <= '0;                     // Clear at burst end
    end else if (s_axis_valid_i && (sym_count_q < WinLen)) begin
      sym_count_q <= sym_count_q + 1'b1;     // Advance on symbol strobe
    end
  end

  // Delay line; last stage stores the conjugate
  logic signed [DataWidth-1:0] re_delay_q [Lag];  // Real delay samples
  logic signed [DataWidth-1:0] im_delay_q [Lag];  // Imag delay samples

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int k = 0; k < Lag; k++) begin
        re_delay_q[k] <= '0;                 // Clear real delay
        im_delay_q[k] <= '0;                 // Clear imag delay
      end
    end else if (s_axis_valid_i) begin
      re_delay_q[0] <= s_axis_i_sym_i;       // Newest real sample
      im_delay_q[0] <= s_axis_q_sym_i;       // Newest imag sample
      for (int k = 1; k < Lag - 1; k++) begin
        re_delay_q[k] <= re_delay_q[k-1];    // Shift real
        im_delay_q[k] <= im_delay_q[k-1];    // Shift imag
      end
      re_delay_q[Lag-1] <=  re_delay_q[Lag-2];  // Last real stage
      im_delay_q[Lag-1] <= -im_delay_q[Lag-2];  // Last stage: negate Q = conjugate
    end
  end

  // Complex multiply r[n] * conj(r[n-Lag]) - 32-bit output
  logic signed [32:0] mult_re;  // Product real
  logic signed [32:0] mult_im;  // Product imag

  complex_mult #(
    .InWidth (DataWidth),    // 16-bit input
    .OutWidth(33)            // 32-bit output
  ) u_complex_mult (
    .a_re_i (s_axis_i_sym_i),         // Current real
    .a_im_i (s_axis_q_sym_i),         // Current imag
    .b_re_i (re_delay_q[Lag-1]),      // Delayed real
    .b_im_i (im_delay_q[Lag-1]),      // Delayed imag (already conjugated)
    .p_re_o (mult_re),                // Real product
    .p_im_o (mult_im)                 // Imag product
  );

  // Accumulate over WinLen symbols
  logic signed [AccWidth-1:0] acc_re;   // Real sum
  logic signed [AccWidth-1:0] acc_im;   // Imag sum
  logic                       acc_done; // Level: window done

  accumulator #(
    .InWidth (33),           // 32-bit input
    .AccWidth(AccWidth),     // 40-bit accumulator
    .WinLen  (WinLen),       // 32 symbols
    .Lag     (Lag)           // 4 symbols priming
  ) u_accumulator (
    .clk_i   (clk_i),                  // Clock
    .rst_ni  (rst_ni),                 // Reset
    .start_i (start_i),                // New burst
    .valid_i (s_axis_valid_i),         // Symbol strobe
    .in_re_i (mult_re),                // Real product
    .in_im_i (mult_im),                // Imag product
    .out_re_o(acc_re),                 // Real sum
    .out_im_o(acc_im),                 // Imag sum
    .valid_o (acc_done)                // Window done (level)
  );

  // Convert the level to a one-cycle pulse
  logic acc_done_q;      // Previous value
  logic acc_done_pulse;  // Rising-edge pulse

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      acc_done_q <= 1'b0;              // Clear
    end else begin
      acc_done_q <= acc_done;          // One-cycle delay
    end
  end

  assign acc_done_pulse = acc_done & ~acc_done_q;  // Rising edge only

  // CORDIC angle of the accumulated R
  logic signed [23:0] angle_out;   // Angle in fraction-of-turn
  logic               angle_valid; // One-pulse valid

  cordic_angle #(
    .InWidth   (AccWidth),   // 40-bit vector
    .OutWidth  (24),         // 24-bit angle
    .Iterations(16)          // 16 iterations
  ) u_cordic_angle (
    .clk_i  (clk_i),                  // Clock
    .rst_ni (rst_ni),                 // Reset
    .start_i(acc_done_pulse),         // Single-cycle start
    .x_i    (acc_re),                 // Real accum
    .y_i    (acc_im),                 // Imag accum
    .angle_o(angle_out),              // Angle out
    .valid_o(angle_valid)             // Valid out
  );

  // Divide by lag D=4 => turns per symbol; then register output
  logic signed [23:0] cfo_q;       // Held estimate
  logic               cfo_valid_q; // Held valid

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cfo_q       <= '0;              // Clear
      cfo_valid_q <= 1'b0;            // Clear
    end else begin
      cfo_valid_q <= angle_valid;     // Pass valid through
      if (force_cfo_en_i) begin
        cfo_q <= force_cfo_i;         // DFT force override
      end else if (angle_valid) begin
        cfo_q <= angle_out >>> 2;     // Divide by 4
      end
    end
  end

  assign m_axis_cfo_o   = cfo_q;        // Output estimate
  assign m_axis_valid_o = cfo_valid_q;  // One-pulse ready

endmodule 
