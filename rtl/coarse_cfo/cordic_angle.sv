////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         A cordic_angle module.
// Date:           8-11-2026
// Description:    Iterative CORDIC atan2(y, x); output is a fraction of a turn.
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////

module cordic_angle #(
    parameter int unsigned InWidth    = 40,  // Input vector width come from the output width of accumulator
    parameter int unsigned OutWidth   = 24,  // Angle width (fraction of turn)
    parameter int unsigned Iterations = 16   // CORDIC iterations
  ) (
    input  logic clk_i,                       // Clock
    input  logic rst_ni,                      // Async reset, active low
    input  logic start_i,                     // Start a new angle computation
    input  logic signed [InWidth-1:0]  x_i,   // x input (real)
    input  logic signed [InWidth-1:0]  y_i,   // y input (imag)
    output logic signed [OutWidth-1:0] angle_o, // Angle output
    output logic                       valid_o  // One-cycle pulse
  );

    localparam int unsigned IterWidth = $clog2(Iterations > 1 ? Iterations : 2);
    localparam logic signed [OutWidth-1:0] PiConst = $signed({1'b0, {(OutWidth-1){1'b1}}});

    // FSM states
    typedef enum logic [1:0] {
      StIdle,      // Wait for start_i
      StIterate,   // Rotate x/y
      StDone       // Apply quadrant correction
    } cordic_state_e;

    cordic_state_e state_q, state_d;  // Current and next state

    localparam logic signed [OutWidth-1:0] ATAN_0  = (OutWidth <= 24) ? OutWidth'(24'sd2097152 >>> (24 - OutWidth)) : (OutWidth'(24'sd2097152) <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_1  = (OutWidth <= 24) ? OutWidth'(24'sd1237935 >>> (24 - OutWidth)) : (OutWidth'(24'sd1237935) <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_2  = (OutWidth <= 24) ? OutWidth'(24'sd653967  >>> (24 - OutWidth)) : (OutWidth'(24'sd653967)  <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_3  = (OutWidth <= 24) ? OutWidth'(24'sd331868  >>> (24 - OutWidth)) : (OutWidth'(24'sd331868)  <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_4  = (OutWidth <= 24) ? OutWidth'(24'sd166564  >>> (24 - OutWidth)) : (OutWidth'(24'sd166564)  <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_5  = (OutWidth <= 24) ? OutWidth'(24'sd83364   >>> (24 - OutWidth)) : (OutWidth'(24'sd83364)   <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_6  = (OutWidth <= 24) ? OutWidth'(24'sd41688   >>> (24 - OutWidth)) : (OutWidth'(24'sd41688)   <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_7  = (OutWidth <= 24) ? OutWidth'(24'sd20844   >>> (24 - OutWidth)) : (OutWidth'(24'sd20844)   <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_8  = (OutWidth <= 24) ? OutWidth'(24'sd10422   >>> (24 - OutWidth)) : (OutWidth'(24'sd10422)   <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_9  = (OutWidth <= 24) ? OutWidth'(24'sd5211    >>> (24 - OutWidth)) : (OutWidth'(24'sd5211)    <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_10 = (OutWidth <= 24) ? OutWidth'(24'sd2605    >>> (24 - OutWidth)) : (OutWidth'(24'sd2605)    <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_11 = (OutWidth <= 24) ? OutWidth'(24'sd1302    >>> (24 - OutWidth)) : (OutWidth'(24'sd1302)    <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_12 = (OutWidth <= 24) ? OutWidth'(24'sd651     >>> (24 - OutWidth)) : (OutWidth'(24'sd651)     <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_13 = (OutWidth <= 24) ? OutWidth'(24'sd325     >>> (24 - OutWidth)) : (OutWidth'(24'sd325)     <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_14 = (OutWidth <= 24) ? OutWidth'(24'sd162     >>> (24 - OutWidth)) : (OutWidth'(24'sd162)     <<< (OutWidth - 24));
    localparam logic signed [OutWidth-1:0] ATAN_15 = (OutWidth <= 24) ? OutWidth'(24'sd81      >>> (24 - OutWidth)) : (OutWidth'(24'sd81)      <<< (OutWidth - 24));

    // atan(2^-i) fraction-of-turn LUT scaled to OutWidth (full turn = 2^OutWidth, pi = 2^(OutWidth-1)).
    function automatic logic signed [OutWidth-1:0] atan_lut(input logic [IterWidth-1:0] idx);
      logic signed [OutWidth-1:0] val;  // Return value
      unique case (idx)
        IterWidth'(0):    val = ATAN_0;     // 45.000 deg
        IterWidth'(1):    val = ATAN_1;     // 26.565 deg
        IterWidth'(2):    val = ATAN_2;     // 14.036 deg
        IterWidth'(3):    val = ATAN_3;     // 7.125 deg
        IterWidth'(4):    val = ATAN_4;     // 3.576 deg
        IterWidth'(5):    val = ATAN_5;     // 1.790 deg
        IterWidth'(6):    val = ATAN_6;     // 0.895 deg
        IterWidth'(7):    val = ATAN_7;     // 0.448 deg
        IterWidth'(8):    val = ATAN_8;     // 0.224 deg
        IterWidth'(9):    val = ATAN_9;     // 0.112 deg
        IterWidth'(10):   val = ATAN_10;    // 0.056 deg
        IterWidth'(11):   val = ATAN_11;    // 0.028 deg
        IterWidth'(12):   val = ATAN_12;    // 0.014 deg
        IterWidth'(13):   val = ATAN_13;    // 0.007 deg
        IterWidth'(14):   val = ATAN_14;    // 0.003 deg
        IterWidth'(15):   val = ATAN_15;    // 0.002 deg
        default:          val = '0;         // Unreachable when Iterations == 16
      endcase
      return val;
    endfunction

    logic [IterWidth-1:0]       iter_q;    // Iteration counter
    logic signed [InWidth-1:0]  x_q, x_d;  // Working x
    logic signed [InWidth-1:0]  y_q, y_d;  // Working y
    logic signed [OutWidth-1:0] z_q, z_d;  // Accumulated angle
    logic                       sign_x_q;  // Saved sign of x_in
    logic                       sign_y_q;  // Saved sign of y_in
    logic                       valid_q;   // Registered valid

    // Combinational next state and datapath
    always_comb begin
      state_d = state_q;    // Default: stay
      x_d     = x_q;        // Default: hold
      y_d     = y_q;        // Default: hold
      z_d     = z_q;        // Default: hold

      unique case (state_q)
        StIdle: begin
          if (start_i) begin
            state_d = StIterate;  // Begin iteration
          end
        end

        StIterate: begin
          if (y_q > 0) begin
            x_d = x_q + (y_q >>> iter_q);  // Rotate +ve
            y_d = y_q - (x_q >>> iter_q);  // Rotate +ve
            z_d = z_q + atan_lut(iter_q);  // Add atan
          end else begin
            x_d = x_q - (y_q >>> iter_q);  // Rotate -ve
            y_d = y_q + (x_q >>> iter_q);  // Rotate -ve
            z_d = z_q - atan_lut(iter_q);  // Subtract atan
          end
          if (iter_q == Iterations - 1) begin
            state_d = StDone;             // Finish iterations
          end
        end

        StDone: begin
          state_d = StIdle;               // Return to idle
        end

        default: state_d = StIdle;        // Safe default
      endcase
    end

    // Sequential state, datapath and output registers
    always_ff @(posedge clk_i) begin
      if (!rst_ni) begin
        state_q  <= StIdle;   // Start in idle
        valid_q  <= 1'b0;     // No valid yet
        angle_o  <= '0;       // Clear output
        x_q      <= '0;       // Clear x
        y_q      <= '0;       // Clear y
        z_q      <= '0;       // Clear angle
        iter_q   <= '0;       // Clear iteration
        sign_x_q <= 1'b0;     // Clear sign
        sign_y_q <= 1'b0;     // Clear sign
      end else begin
        state_q <= state_d;   // Advance state

        unique case (state_q)
          StIdle: begin
            valid_q <= 1'b0;  // Idle clears valid
            if (start_i) begin
              x_q      <= (x_i < 0) ? -x_i : x_i;  // Take abs(x)
              y_q      <= (y_i < 0) ? -y_i : y_i;  // Take abs(y)
              sign_x_q <= x_i[InWidth-1];          // Save sign of x
              sign_y_q <= y_i[InWidth-1];          // Save sign of y
              z_q      <= '0;                      // Reset angle
              iter_q   <= '0;                      // Reset iteration
            end
          end

          StIterate: begin
            x_q <= x_d;       // Update x
            y_q <= y_d;       // Update y
            z_q <= z_d;       // Update angle
            if (iter_q < Iterations - 1) begin
              iter_q <= iter_q + 1'b1;  // Next iteration
            end
          end

          StDone: begin
            if (!sign_x_q && !sign_y_q) begin
              angle_o <= z_q;                  // Q1: as is
            end else if (!sign_x_q && sign_y_q) begin
              angle_o <= -z_q;                 // Q4: negate
            end else if (sign_x_q && !sign_y_q) begin
              angle_o <= PiConst - z_q;   // Q2: pi - z
            end else begin
              angle_o <= -PiConst + z_q;  // Q3: -pi + z
            end
            valid_q <= 1'b1;                    // Pulse valid
          end

          default: ;        // Nothing to do
        endcase
      end
    end

    assign valid_o = valid_q;  // Output valid pulse

endmodule 