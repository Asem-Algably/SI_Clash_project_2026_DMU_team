////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A top system module.
// Date: 6-11-2026
// Description: Top level chain: connects STR to coarse CFO to Costas loop.
////////////////////////////////////////////////////////////////////////////////


module sync_system_top (
    input  logic clk_i,                         // System clock
    input  logic rst_ni,                        // Async reset, active low
    input  logic signed [11:0] adc_re_i,        // ADC real sample
    input  logic signed [11:0] adc_im_i,        // ADC imag sample
    input  logic               adc_valid_i,     // ADC strobe
    input  logic start_of_burst_i,              // Burst start
    output logic signed [15:0] out_re_o,        // Symbol real out
    output logic signed [15:0] out_im_o,        // Symbol imag out
    output logic               out_valid_o      // Symbol strobe out
  );

    // Synchronized reset
    logic rst_n_sync;

    reset_sync u_reset_sync (
      .clk_i (clk_i),        // System clock
      .rst_ni(rst_ni),       // External reset
      .rst_no(rst_n_sync)    // Synchronized reset
    );

    // STR output interface
    logic signed [15:0] str_out_re;     // STR real
    logic signed [15:0] str_out_im;     // STR imag
    logic               str_out_valid;  // STR strobe

    // Coarse CFO interface
    logic signed [23:0] coarse_cfo_freq_word;  // Estimate word
    logic               coarse_cfo_valid;      // Estimate pulse

    // Symbol timing recovery
    str_gardner_top u_str_gardner_top (
      .clk_i      (clk_i),            // Clock
      .rst_ni     (rst_n_sync),       // Reset
      .in_re_i    (adc_re_i),         // ADC real
      .in_im_i    (adc_im_i),         // ADC imag
      .in_valid_i (adc_valid_i),      // ADC strobe
      .out_re_o   (str_out_re),       // Symbol real
      .out_im_o   (str_out_im),       // Symbol imag
      .out_valid_o(str_out_valid)     // Symbol strobe
    );

    // Coarse CFO estimator
    coarse_cfo_core u_coarse_cfo_core (
      .clk_i           (clk_i),                   // Clock
      .rst_ni          (rst_n_sync),              // Reset
      .start_i         (start_of_burst_i),        // Burst start
      .s_axis_valid_i  (str_out_valid),           // Symbol strobe
      .s_axis_i_sym_i  (str_out_re),              // Symbol real
      .s_axis_q_sym_i  (str_out_im),              // Symbol imag
      .m_axis_valid_o  (coarse_cfo_valid),        // Estimate pulse
      .m_axis_cfo_o    (coarse_cfo_freq_word),    // Estimate word
      .force_cfo_en_i  (1'b0),                    // Force disabled
      .force_cfo_i     (24'sd0)                   // Force value unused
    );

    // Costas loop; uses CFO estimate as initial frequency word
    costas_loop_top u_costas_loop_top (
      .clk_i            (clk_i),                   // Clock
      .rst_ni           (rst_n_sync),              // Reset
      .in_re_i          (str_out_re),              // Symbol real
      .in_im_i          (str_out_im),              // Symbol imag
      .in_valid_i       (str_out_valid),           // Symbol strobe
      .init_freq_word_i (coarse_cfo_freq_word),    // Initial frequency
      .init_freq_valid_i(coarse_cfo_valid),        // Load initial word
      .out_re_o         (out_re_o),                // Derotated real
      .out_im_o         (out_im_o),                // Derotated imag
      .out_valid_o      (out_valid_o)              // Output strobe
    );

endmodule 