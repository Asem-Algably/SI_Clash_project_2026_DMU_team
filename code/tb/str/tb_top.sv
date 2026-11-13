`timescale 1ns / 1ps

module tb_top;
  parameter int CLK_PERIOD = 10; // 100 MHz (ASIC Target)

  // Inputs
  logic clk_i;
  logic rst_ni;
  logic s_axis_valid_i;
  logic [11:0] s_axis_i_sample_i;
  logic [11:0] s_axis_q_sample_i;
  logic [7:0] loop_gain_i;

  // Outputs
  logic m_axis_valid_o;
  logic [15:0] m_axis_i_sym_o;
  logic [15:0] m_axis_q_sym_o;
  logic lock_o;
  logic ted_err_valid_o;
  logic [31:0] ted_err_o;
  logic [9:0] mu_o;
  logic [15:0] w_o;

  // DFT Force
  logic force_w_en_i;
  logic [15:0] force_w_i;

  // Instantiate Top DUT
  top dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .s_axis_valid_i(s_axis_valid_i),
    .s_axis_i_sample_i(s_axis_i_sample_i),
    .s_axis_q_sample_i(s_axis_q_sample_i),
    .loop_gain_i(loop_gain_i),
    .m_axis_valid_o(m_axis_valid_o),
    .m_axis_i_sym_o(m_axis_i_sym_o),
    .m_axis_q_sym_o(m_axis_q_sym_o),
    .lock_o(lock_o),
    .ted_err_valid_o(ted_err_valid_o),
    .ted_err_o(ted_err_o),
    .mu_o(mu_o),
    .w_o(w_o),
    .force_w_en_i(force_w_en_i),
    .force_w_i(force_w_i)
  );

  // Clock generation
  initial clk_i = 0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  // ---------------------------------------------------------
  // Internal QPSK Data Generator (Self-Contained)
  // ---------------------------------------------------------
  // We simulate a signal with 4 samples per symbol.
  // The symbols are pseudo-random QPSK.
  // We introduce a slight timing offset to let the loop lock.
  
  real pi_val = 3.1415926535;
  int sample_cnt = 0;
  int symbol_idx = 0;
  
  // Simple QPSK constellation
  logic signed [11:0] qpsk_i [0:3] = '{12'sd300, 12'sd300, -12'sd300, -12'sd300};
  logic signed [11:0] qpsk_q [0:3] = '{12'sd300, -12'sd300, 12'sd300, -12'sd300};

  // Generate a simple pulse (e.g., just hold the symbol, or a simple RC pulse)
  // For simplicity, we feed the symbol value 4 times (Rectangular pulse)
  // The interpolator and loop should be able to lock onto this.
  
  // To simulate a timing offset, we will shift the sample stream slightly.
  // A simple way is to use a fractional delay in the signal itself or just
  // run the loop. The loop will lock if there is a real transition.
  
  initial begin
    // Initialize Inputs
    rst_ni = 0;
    s_axis_valid_i = 0;
    s_axis_i_sample_i = 0;
    s_axis_q_sample_i = 0;
    loop_gain_i = 8'd0;
    force_w_en_i = 0;
    force_w_i = 0;

    #(CLK_PERIOD * 5);
    rst_ni = 1;
    #(CLK_PERIOD * 5);

    $display("Starting STR Top Level Test...");

    // Drive 5000 samples (1250 symbols)
    for (int i = 0; i < 5000; i++) begin
      @(posedge clk_i);
      s_axis_valid_i = 1;
      
      // Determine which symbol to send
      if (i % 4 == 0) begin
        symbol_idx = $urandom % 4;
      end
      
      // Add some simulated noise
      s_axis_i_sample_i = qpsk_i[symbol_idx] + ($urandom % 20);
      s_axis_q_sample_i = qpsk_q[symbol_idx] + ($urandom % 20);
      
      @(posedge clk_i);
      s_axis_valid_i = 0;
      #(CLK_PERIOD * 2); // Gap between valid samples to match the system
    end

    // Let the loop run for a bit to settle
    #(CLK_PERIOD * 1000);
    
    $display("Test Complete.");
    $finish;
  end

  // ---------------------------------------------------------
  // Monitor / Scoreboard
  // ---------------------------------------------------------
  int locked_cnt = 0;
  always @(posedge clk_i) begin
    if (lock_o) begin
      locked_cnt++;
      if (locked_cnt == 1) $display("Time: %0t | LOCK ACHIEVED!", $time);
    end
    
    if (m_axis_valid_o) begin
      $display("Time: %0t | SYMBOL OUT: I=%0d, Q=%0d | mu=%0d", $time, $signed(m_axis_i_sym_o), $signed(m_axis_q_sym_o), mu_o);
    end
    
    // Monitor TED error convergence
    if (ted_err_valid_o && (locked_cnt > 0) && (locked_cnt < 10)) begin
        $display("Time: %0t | TED Error: %0d | W: %0d", $time, $signed(ted_err_o), $signed(w_o));
    end
  end

  // Optional: Use external files as in the reference
  /*
  parameter LEN = 4000;
  reg [11:0] data_I [LEN-1:0];
  reg [11:0] data_Q [LEN-1:0];
  
  initial begin
    $readmemb("dataI.txt", data_I);
    $readmemb("dataQ.txt", data_Q);
    // ... add loop to feed data
  end
  */
endmodule