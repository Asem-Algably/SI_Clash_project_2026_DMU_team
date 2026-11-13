`timescale 1ns / 1ps

module tb_pI_loop;
  parameter int CLK_PERIOD = 10;

  logic clk_i;
  logic rst_n_i;
  logic valid_i;
  logic signed [31:0] error_i;
  logic signed [15:0] pi_o;

  pI_loop dut (
    .clk_i(clk_i),
    .rst_ni(rst_n_i),    
    .valid_i(valid_i),
    .error_i(error_i),
    .pi_o(pi_o)
  );

  initial clk_i = 0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  initial begin
    rst_n_i = 0;
    valid_i = 0;
    error_i = 0;
    
    #(CLK_PERIOD * 2);
    rst_n_i = 1;
    #(CLK_PERIOD * 2);

    // Apply a constant positive error to drive the loop to saturation
    $display("Applying constant positive error...");
    for (int i = 0; i < 20; i++) begin
      @(posedge clk_i);
      valid_i = 1;
      error_i = 32'sd10000; // Large error
      @(posedge clk_i);
      valid_i = 0;
      #(CLK_PERIOD * 2);
    end

    // Apply negative error to unwind
    $display("Applying negative error...");
    for (int i = 0; i < 20; i++) begin
      @(posedge clk_i);
      valid_i = 1;
      error_i = -32'sd10000;
      @(posedge clk_i);
      valid_i = 0;
      #(CLK_PERIOD * 2);
    end

    #(CLK_PERIOD * 5);
    $display("Test Complete.");
    $finish;
  end

  always @(posedge clk_i) begin
    if (valid_i) begin
      $display("Time: %0t | Error: %0d | PI Output: %0d", $time, error_i, pi_o);
    end
  end
endmodule