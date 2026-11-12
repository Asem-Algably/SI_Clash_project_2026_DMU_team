`timescale 1ns / 1ps

module tb_gardner_ted_estimator;
  parameter int CLK_PERIOD = 10;

  logic clk_i;
  logic rst_n_i;
  logic valid_i;
  logic signed [15:0] i_mid_i, q_mid_i;
  logic signed [15:0] i_cur_i, q_cur_i;
  logic signed [15:0] i_prev_i, q_prev_i;
  logic signed [31:0] error_o;
  logic error_valid_o;

  gardner_ted_estimator dut (
    .clk_i(clk_i), .rst_ni(rst_n_i), .valid_i(valid_i),
    .i_mid_i(i_mid_i), .q_mid_i(q_mid_i),
    .i_cur_i(i_cur_i), .q_cur_i(q_cur_i),
    .i_prev_i(i_prev_i), .q_prev_i(q_prev_i),
    .error_o(error_o), .error_valid_o(error_valid_o)
  );

  initial clk_i = 0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  initial begin
    rst_n_i = 0;
    valid_i = 0;
    i_mid_i = 0; q_mid_i = 0;
    i_cur_i = 0; q_cur_i = 0;
    i_prev_i = 0; q_prev_i = 0;
    
    #(CLK_PERIOD * 2);
    rst_n_i = 1;
    #(CLK_PERIOD * 2);

    // Test Case 1: Positive Timing Error (Late)
    // cur > prev, mid > 0
    @(posedge clk_i);
    valid_i = 1;
    i_mid_i = 16'sd100;
    i_cur_i = 16'sd500;
    i_prev_i = 16'sd200;
    q_mid_i = 16'sd50;
    q_cur_i = 16'sd100;
    q_prev_i = 16'sd50;
    @(posedge clk_i);
    valid_i = 0;
    #(CLK_PERIOD * 5);

    // Test Case 2: Negative Timing Error (Early)
    // cur < prev, mid > 0
    @(posedge clk_i);
    valid_i = 1;
    i_mid_i = 16'sd100;
    i_cur_i = 16'sd200;
    i_prev_i = 16'sd500;
    q_mid_i = 16'sd50;
    q_cur_i = 16'sd50;
    q_prev_i = 16'sd100;
    @(posedge clk_i);
    valid_i = 0;
    #(CLK_PERIOD * 5);

    $display("Test Complete.");
    $finish;
  end

  always @(posedge clk_i) begin
    if (error_valid_o) begin
      $display("Time: %0t | TED Error: %0d", $time, error_o);
    end
  end
endmodule