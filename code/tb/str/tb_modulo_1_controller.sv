`timescale 1ns / 1ps

module tb_modulo_1_controller;
  parameter int MU_WIDTH = 10;
  parameter int CLK_PERIOD = 10;

  logic clk_i;
  logic rst_n_i;
  logic valid_sample_i;
  logic signed [15:0] pi_i;
  logic [MU_WIDTH-1:0] mu_o;
  logic mid_strobe_o;
  logic current_strobe_o;
  logic signed [15:0] w_o;

  modulo_1_controller #(.MU_WIDTH(MU_WIDTH)) dut (
    .clk_i(clk_i),
    .rst_ni(rst_n_i),         
    .valid_sample_i(valid_sample_i),
    .pi_i(pi_i),
    .mu_o(mu_o),
    .mid_strobe_o(mid_strobe_o),
    .current_strobe_o(current_strobe_o),
    .w_o(w_o)
  );

  initial clk_i = 0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  initial begin
    rst_n_i = 0;
    valid_sample_i = 0;
    pi_i = 0; // No frequency offset, W = 0.25
    
    #(CLK_PERIOD * 2);
    rst_n_i = 1;
    #(CLK_PERIOD * 2);

    // Feed 20 valid samples
    for (int i = 0; i < 20; i++) begin
      @(posedge clk_i);
      valid_sample_i = 1;
      @(posedge clk_i);
      valid_sample_i = 0;
      #(CLK_PERIOD * 2); // Gap between samples
    end

    #(CLK_PERIOD * 5);
    $display("Test Complete.");
    $finish;
  end

  // Monitor
  always @(posedge clk_i) begin
    if (valid_sample_i) begin
      $display("Time: %0t | Valid Sample. mu_o = %0d", $time, mu_o);
    end
    if (current_strobe_o) $display("  --> Current Strobe Generated");
    if (mid_strobe_o)     $display("  --> Mid Strobe Generated");
  end
endmodule