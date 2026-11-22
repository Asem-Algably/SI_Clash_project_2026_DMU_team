// ============================================================================
// File Name   : seven_seg_controller.sv
// Module Name : seven_seg_controller
// Project     : SI-CLASH Real-Time Digital Synchronizer - ZCU106 BIST
// Description : Parameterizable 4-digit 7-segment display multiplexer.
//               Operates fully synchronous to the single 200 MHz clock domain
//               using a synchronous prescaler enable pulse (zero CDC).
//               Display format: [Digit 3 | Digit 2 | Digit 1 | Digit 0]
//               where Digits [3:2] = Status Code, Digits [1:0] = Count Hex.
// ============================================================================

`timescale 1ns / 1ps

module seven_seg_controller #(
  parameter bit          CATHODE_ACTIVE_LOW = 1'b1,
  parameter bit          ANODE_ACTIVE_LOW   = 1'b1,
  parameter int unsigned PRESCALER_LIMIT    = 200_000 // 200 MHz / 200,000 = 1 kHz refresh
)(
  input  logic                            clk,
  input  logic                            rst_n,
  input  logic [15:0]                     display_data, // [15:8] Status Code, [7:0] Pass Count Hex
  input  logic [3:0]                      dp_in,        // Decimal points per digit (Active High logical)
  output logic [6:0]                      seg_o,        // Segments {g, f, e, d, c, b, a}
  output logic                            dp_o,         // Decimal point
  output logic [3:0]                      an_o,         // Digit enable anodes [3:0]
  output logic [1:0]                      cur_digit_o,  // Currently active digit (0..3)
  output logic                            pulse_1khz_o  // 1 kHz strobe pulse for debug/tb
);

  // --------------------------------------------------------------------------
  // Prescaler generating synchronous 1 kHz multiplexing strobe
  // --------------------------------------------------------------------------
  localparam int unsigned CNT_WIDTH = $clog2(PRESCALER_LIMIT > 1 ? PRESCALER_LIMIT : 2);
  logic [CNT_WIDTH-1:0] prescaler_cnt;
  logic                 strobe_1khz;
  logic [1:0]           digit_idx;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      prescaler_cnt <= '0;
      strobe_1khz   <= 1'b0;
      digit_idx     <= 2'd0;
    end else begin
      if (prescaler_cnt == (PRESCALER_LIMIT - 1)) begin
        prescaler_cnt <= '0;
        strobe_1khz   <= 1'b1;
        digit_idx     <= digit_idx + 2'd1;
      end else begin
        prescaler_cnt <= prescaler_cnt + 1'b1;
        strobe_1khz   <= 1'b0;
      end
    end
  end

  assign pulse_1khz_o = strobe_1khz;
  assign cur_digit_o  = digit_idx;

  // --------------------------------------------------------------------------
  // Digit Multiplexing & Hex-to-Segment Decoding
  // --------------------------------------------------------------------------
  logic [3:0] current_nibble;
  logic       current_dp;

  always_comb begin
    case (digit_idx)
      2'd0: begin
        current_nibble = display_data[3:0];   // Digit 0 (Lower count nibble)
        current_dp     = dp_in[0];
      end
      2'd1: begin
        current_nibble = display_data[7:4];   // Digit 1 (Upper count nibble)
        current_dp     = dp_in[1];
      end
      2'd2: begin
        current_nibble = display_data[11:8];  // Digit 2 (Lower status nibble)
        current_dp     = dp_in[2];
      end
      2'd3: begin
        current_nibble = display_data[15:12]; // Digit 3 (Upper status nibble)
        current_dp     = dp_in[3];
      end
      default: begin
        current_nibble = 4'h0;
        current_dp     = 1'b0;
      end
    endcase
  end

  // Hex to 7-segment decoder: segments {g, f, e, d, c, b, a}
  function automatic logic [6:0] hex2seg(input logic [3:0] hex);
    case (hex)
      4'h0: hex2seg = 7'b0111111; // 0: a, b, c, d, e, f
      4'h1: hex2seg = 7'b0000110; // 1: b, c
      4'h2: hex2seg = 7'b1011011; // 2: a, b, d, e, g
      4'h3: hex2seg = 7'b1001111; // 3: a, b, c, d, g
      4'h4: hex2seg = 7'b1100110; // 4: b, c, f, g
      4'h5: hex2seg = 7'b1101101; // 5: a, c, d, f, g
      4'h6: hex2seg = 7'b1111101; // 6: a, c, d, e, f, g
      4'h7: hex2seg = 7'b0000111; // 7: a, b, c
      4'h8: hex2seg = 7'b1111111; // 8: a, b, c, d, e, f, g
      4'h9: hex2seg = 7'b1101111; // 9: a, b, c, d, f, g
      4'hA: hex2seg = 7'b1110111; // A: a, b, c, e, f, g
      4'hB: hex2seg = 7'b1111100; // b: c, d, e, f, g
      4'hC: hex2seg = 7'b0111001; // C: a, d, e, f
      4'hD: hex2seg = 7'b1011110; // d: b, c, d, e, g
      4'hE: hex2seg = 7'b1111001; // E: a, d, e, f, g
      4'hF: hex2seg = 7'b1110001; // F: a, e, f, g
      default: hex2seg = 7'b0000000;
    endcase
  endfunction

  // --------------------------------------------------------------------------
  // Output Registers with Parameterizable Active Polarity
  // --------------------------------------------------------------------------
  logic [6:0] raw_seg;
  logic [3:0] raw_an;

  always_comb begin
    raw_seg = hex2seg(current_nibble);
    raw_an  = (4'b0001 << digit_idx);
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      seg_o <= CATHODE_ACTIVE_LOW ? 7'b1111111 : 7'b0000000;
      dp_o  <= CATHODE_ACTIVE_LOW ? 1'b1 : 1'b0;
      an_o  <= ANODE_ACTIVE_LOW   ? 4'b1111 : 4'b0000;
    end else begin
      seg_o <= CATHODE_ACTIVE_LOW ? ~raw_seg : raw_seg;
      dp_o  <= CATHODE_ACTIVE_LOW ? ~current_dp : current_dp;
      an_o  <= ANODE_ACTIVE_LOW   ? ~raw_an : raw_an;
    end
  end

endmodule
