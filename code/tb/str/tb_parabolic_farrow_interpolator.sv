`timescale 1ns / 1ps

module tb_parabolic_farrow_interpolator;
  // Parameters
  parameter int DATA_IN_INTEGER_WIDTH = 1;
  parameter int DATA_IN_FRACTIONAL_WIDTH = 11;
  parameter int DATA_OUT_INTEGER_WIDTH = 1;
  parameter int DATA_OUT_FRACTIONAL_WIDTH = 15;
  parameter int MU_WIDTH = 10;
  parameter int CLK_PERIOD = 10; // 100 MHz

  // Signals
  logic clk_i;
  logic rst_n_i;
  logic valid_sample_i;
  
  logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x_i;
  logic [MU_WIDTH-1:0] mu_i;
  logic signed [DATA_OUT_INTEGER_WIDTH-1:-DATA_OUT_FRACTIONAL_WIDTH] y_o;
  logic valid_sample_o;

  // Instantiate DUT
  parabolic_farrow_interpolator #(
    .DATA_IN_INTEGER_WIDTH(DATA_IN_INTEGER_WIDTH),
    .DATA_IN_FRACTIONAL_WIDTH(DATA_IN_FRACTIONAL_WIDTH),
    .DATA_OUT_INTEGER_WIDTH(DATA_OUT_INTEGER_WIDTH),
    .DATA_OUT_FRACTIONAL_WIDTH(DATA_OUT_FRACTIONAL_WIDTH),
    .MU_WIDTH(MU_WIDTH)
  ) dut (
    .clk_i(clk_i),
    .rst_n_i(rst_n_i),
    .valid_sample_i(valid_sample_i),
    .x_i(x_i),
    .mu_i(mu_i),
    .y_o(y_o),
    .valid_sample_o(valid_sample_o)
  );

  // Clock generation
  initial clk_i = 0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  // Test sequence
  initial begin
    // Initialize
    rst_n_i = 0;
    valid_sample_i = 0;
    x_i = '0;
    mu_i = 10'h200; // 0.5 in Q1.10 (512)
    
    #(CLK_PERIOD * 2);
    rst_n_i = 1;
    #(CLK_PERIOD * 2);

    // Apply test samples
    // Sample 1
    @(posedge clk_i);
    x_i = 12'sh100; // 0.125 in Q1.11
    valid_sample_i = 1;
    @(posedge clk_i);
    valid_sample_i = 0;
    
    // Sample 2
    @(posedge clk_i);
    x_i = 12'sh200; // 0.25
    valid_sample_i = 1;
    @(posedge clk_i);
    valid_sample_i = 0;

    // Sample 3
    @(posedge clk_i);
    x_i = 12'sh300; // 0.375
    valid_sample_i = 1;
    @(posedge clk_i);
    valid_sample_i = 0;

    // Sample 4
    @(posedge clk_i);
    x_i = 12'sh400; // 0.5
    valid_sample_i = 1;
    @(posedge clk_i);
    valid_sample_i = 0;

    // Sample 5
    @(posedge clk_i);
    x_i = 12'sh500; // 0.625
    valid_sample_i = 1;
    @(posedge clk_i);
    valid_sample_i = 0;

    // Wait for pipeline to flush
    #(CLK_PERIOD * 10);
    $display("Test Complete.");
    $finish;
  end

  // Monitor
  always @(posedge clk_i) begin
    if (valid_sample_o) begin
      $display("Time: %0t | Interpolated y_o = %h (Decimal: %0d)", $time, y_o, $signed(y_o));
    end
  end
endmodule