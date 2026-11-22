////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A testbench of checkpoint3 module.
// Date: 10-11-2026
// Description: Coarse CFO Sweep Verification with File I/O output.
////////////////////////////////////////////////////////////////////////////////

module tb_checkpoint3_full;

  // ---------------------------------------------------------------------------
  // Parameters and Constants
  // ---------------------------------------------------------------------------
  parameter int unsigned DataWidth = 16;  // Symbol width
  parameter int unsigned Lag       = 4;   // Must match DUT Lag
  parameter int unsigned WinLen    = 64;  // Must match DUT WinLen

  localparam int unsigned AMPLITUDE = 10000;             // Sine wave amplitude
  localparam string       FILE_NAME = "cfo_output_tb3.txt"; // Output file

  // ---------------------------------------------------------------------------
  // Clock and Reset
  // ---------------------------------------------------------------------------
  logic clk;     // 125 MHz clock
  logic rst_ni;  // Active-low reset

  // ---------------------------------------------------------------------------
  // AXI4-Stream Signals
  // ---------------------------------------------------------------------------
  logic signed [DataWidth-1:0] s_axis_i_sym;  // I symbol to DUT
  logic signed [DataWidth-1:0] s_axis_q_sym;  // Q symbol to DUT
  logic                        s_axis_valid;  // Symbol strobe to DUT
  logic                        start_i;       // Burst start to DUT

  logic signed [23:0]          m_axis_cfo;    // DUT estimate out
  logic                        m_axis_valid;  // DUT estimate valid

  // ---------------------------------------------------------------------------
  // Testbench Variables
  // ---------------------------------------------------------------------------
  integer file_handle;    // File handle for output
  real    injected_cfo;   // CFO fed to DUT, in Rsym

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  coarse_cfo_core #(
    .DataWidth(DataWidth),
    .Lag      (Lag),
    .WinLen   (WinLen)
  ) u_dut (
    .clk_i          (clk),
    .rst_ni         (rst_ni),
    .start_i        (start_i),
    .s_axis_valid_i (s_axis_valid),
    .s_axis_i_sym_i (s_axis_i_sym),
    .s_axis_q_sym_i (s_axis_q_sym),
    .m_axis_valid_o (m_axis_valid),
    .m_axis_cfo_o   (m_axis_cfo),
    .force_cfo_en_i (1'b0),
    .force_cfo_i    (24'sd0)
  );

  // ---------------------------------------------------------------------------
  // Clock Generation
  // ---------------------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #4 clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // File Output Logic
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (m_axis_valid) begin
      // Save: Injected CFO (Real), Output Raw (Hex), Output Raw (Decimal)
      $fdisplay(file_handle, "%f %h %d", injected_cfo, m_axis_cfo, $signed(m_axis_cfo));
    end
  end

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------
  task automatic apply_reset();
    rst_ni       = 1'b0;
    s_axis_valid = 1'b0;
    s_axis_i_sym = '0;
    s_axis_q_sym = '0;
    start_i      = 1'b0;
    
    repeat (5) @(posedge clk);
    rst_ni = 1'b1;
    repeat (2) @(posedge clk);
  endtask : apply_reset

  task automatic send_pure_tone(input real cfo_freq);
    real phase;
    int  i_val;
    int  q_val;

    for (int n = 0; n < WinLen; n++) begin
      phase        = 2.0 * 3.1415926535 * cfo_freq * n;
      i_val        = $rtoi(AMPLITUDE * $cos(phase));
      q_val        = $rtoi(AMPLITUDE * $sin(phase));
      
      s_axis_i_sym = DataWidth'(i_val);
      s_axis_q_sym = DataWidth'(q_val);
      s_axis_valid = 1'b1;
      
      @(posedge clk);
    end
    s_axis_valid = 1'b0;  // Stop driving after the window
  endtask : send_pure_tone

  // ---------------------------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------------------------
  initial begin
    int unsigned timeout_cnt;
    real         captured_as_rsym;
    int          captured_raw;
    int unsigned num_tests;

    num_tests = 0;

    // Open file for writing
    file_handle = $fopen(FILE_NAME, "w");
    if (file_handle == 0) begin
      $display("Error: Could not open %s", FILE_NAME);
      $finish;
    end

    $display("==========================================================");
    $display(" Coarse CFO Sweep - pure tone, no SNR, no comparison");
    $display("==========================================================");
    $display(" CFO_in (Rsym) |  raw (24-bit) | est_as_Rsym");
    $display("----------------------------------------------------------");

    for (real cfo = -0.10; cfo <= 0.1001; cfo += 0.025) begin
      apply_reset();                // Clean slate for this point
      injected_cfo = cfo;           // Save for file output
      start_i      = 1'b1;          // Enable the window

      send_pure_tone(injected_cfo); // Drive WinLen samples

      // Wait for the DUT estimate (with timeout)
      timeout_cnt = 0;
      while ((m_axis_valid !== 1'b1) && (timeout_cnt < 500)) begin
        @(posedge clk);
        timeout_cnt++;
      end

      if (m_axis_valid === 1'b1) begin
        captured_raw     = $signed(m_axis_cfo);
        captured_as_rsym = real'(captured_raw) / (Lag * (2.0**22));
        
        $display(" %s%0.4f      | %0d    | %s%0.6f",
                 (cfo              < 0.0) ? "" : "+", cfo,
                 captured_raw,
                 (captured_as_rsym < 0.0) ? "" : "+", captured_as_rsym);
      end else begin
        $display(" %s%0.4f      | TIMEOUT           | -",
                 (cfo < 0.0) ? "" : "+", cfo);
      end

      num_tests++;
      start_i = 1'b0;                       // Clear window for next iteration
      repeat (10) @(posedge clk);           // Give the pipeline time to drain
    end

    $display("----------------------------------------------------------");
    $display(" Total CFO points : %0d", num_tests);
    $display("==========================================================");
    
    // Close the file
    $fclose(file_handle);
    $finish;
  end

  // ---------------------------------------------------------------------------
  // Bonus Checkpoint 4.2 Gate-Level Power Analysis
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("coarse_cfo.vcd");
    $dumpvars(0, tb_checkpoint3_full.u_dut);  // Dump DUT signals only
  end

endmodule 