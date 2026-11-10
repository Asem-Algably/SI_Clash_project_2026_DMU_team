////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A testbench of checkpoint5 module.
// Date: 10-11-2026
// Description: DFT MUX & AXI Interface Verification with File I/O output.
////////////////////////////////////////////////////////////////////////////////

module tb_checkpoint5_dft;

  // ---------------------------------------------------------------------------
  // Parameters and Constants
  // ---------------------------------------------------------------------------
  localparam int unsigned AMPLITUDE  = 10000;             // Sine wave amplitude
  localparam real        CFO_FREQ   = 0.05;              // Injected CFO (Rsym)
  localparam int unsigned NUM_SYMS   = 65;                // 64 window + 1 pipeline
  localparam string       FILE_NAME = "cfo_output_tb5.txt"; // Output file

  // ---------------------------------------------------------------------------
  // Clock and Reset
  // ---------------------------------------------------------------------------
  logic clk;     // 125 MHz clock
  logic rst_ni;  // Active-low reset

  // ---------------------------------------------------------------------------
  // AXI4-Lite Signals
  // ---------------------------------------------------------------------------
  logic [5:0]  awaddr;
  logic [2:0]  awprot;
  logic        awvalid;
  logic        awready;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wvalid;
  logic        wready;
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;
  logic [5:0]  araddr;
  logic [2:0]  arprot;
  logic        arvalid;
  logic        arready;
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready;

  // ---------------------------------------------------------------------------
  // AXI4-Stream Signals
  // ---------------------------------------------------------------------------
  logic signed [15:0] s_axis_tdata_re;  // I symbol
  logic signed [15:0] s_axis_tdata_im;  // Q symbol
  logic               s_axis_tvalid;    // Symbol strobe
  logic               s_axis_tready;    // Symbol accept
  logic               start_of_burst;   // Burst start

  logic signed [23:0] m_axis_cfo_est;   // Estimate out
  logic               m_axis_tvalid;    // Estimate valid

  // ---------------------------------------------------------------------------
  // DFT Signals
  // ---------------------------------------------------------------------------
  logic [3:0]  dft_sel;                 // DFT mux select
  logic [31:0] dft_obs_data;            // DFT observation

  // ---------------------------------------------------------------------------
  // Testbench Variables
  // ---------------------------------------------------------------------------
  integer file_handle;                  // File handle for output

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  coarse_cfo_axi_wrapper #(
    .CSlvAxiDataWidth(32),
    .CSlvAxiAddrWidth(6)
  ) u_dut (
    .s00_axi_aclk   (clk),
    .s00_axi_aresetn(rst_ni),
    
    .s00_axi_awaddr (awaddr),
    .s00_axi_awprot (awprot),
    .s00_axi_awvalid(awvalid),
    .s00_axi_awready(awready),
    
    .s00_axi_wdata  (wdata),
    .s00_axi_wstrb  (wstrb),
    .s00_axi_wvalid (wvalid),
    .s00_axi_wready (wready),
    
    .s00_axi_bresp  (bresp),
    .s00_axi_bvalid (bvalid),
    .s00_axi_bready (bready),
    
    .s00_axi_araddr (araddr),
    .s00_axi_arprot (arprot),
    .s00_axi_arvalid(arvalid),
    .s00_axi_arready(arready),
    
    .s00_axi_rdata  (rdata),
    .s00_axi_rresp  (rresp),
    .s00_axi_rvalid (rvalid),
    .s00_axi_rready (rready),
    
    .s_axis_tdata_re(s_axis_tdata_re),
    .s_axis_tdata_im(s_axis_tdata_im),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tready  (s_axis_tready),
    .start_of_burst (start_of_burst),
    
    .m_axis_cfo_est (m_axis_cfo_est),
    .m_axis_tvalid  (m_axis_tvalid),
    
    .dft_sel        (dft_sel),
    .dft_obs_data   (dft_obs_data)
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
    if (m_axis_tvalid) begin
      // Save: Output Raw (Hex), Output Raw (Decimal)
      $fdisplay(file_handle, "%h %d", m_axis_cfo_est, $signed(m_axis_cfo_est));
    end
  end

  // ---------------------------------------------------------------------------
  // AXI Tasks
  // ---------------------------------------------------------------------------
  task automatic axi_write(input logic [5:0] addr, input logic [31:0] data);
    @(posedge clk);
    awaddr  <= addr;
    awvalid <= 1'b1;
    wdata   <= data;
    wvalid  <= 1'b1;
    bready  <= 1'b1;
    
    wait (awready && wready);
    @(posedge clk);
    awvalid <= 1'b0;
    wvalid  <= 1'b0;
    
    wait (bvalid);
    @(posedge clk);
    bready  <= 1'b0;
  endtask : axi_write

  task automatic axi_read(input logic [5:0] addr, output logic [31:0] data);
    @(posedge clk);
    araddr  <= addr;
    arvalid <= 1'b1;
    rready  <= 1'b1;
    
    wait (arready);
    @(posedge clk);
    arvalid <= 1'b0;
    
    wait (rvalid);
    data = rdata;
    @(posedge clk);
    rready  <= 1'b0;
  endtask : axi_read

  // ---------------------------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------------------------
  initial begin
    logic [31:0] read_data;
    real         phase;

    // 1. Initialize all signals to prevent X states
    rst_ni          = 1'b0;
    awaddr          = '0;
    awprot          = '0;
    awvalid         = 1'b0;
    wdata           = '0;
    wstrb           = 4'hF;
    wvalid          = 1'b0;
    bready          = 1'b0;
    araddr          = '0;
    arprot          = '0;
    arvalid         = 1'b0;
    rready          = 1'b0;
    s_axis_tvalid   = 1'b0;
    s_axis_tdata_re = '0;
    s_axis_tdata_im = '0;
    start_of_burst  = 1'b0;
    dft_sel         = '0;

    // Open file for writing
    file_handle = $fopen(FILE_NAME, "w");
    if (file_handle == 0) begin
      $display("Error: Could not open %s", FILE_NAME);
      $finish;
    end

    repeat (5) @(posedge clk);
    rst_ni = 1'b1;
    repeat (2) @(posedge clk);

    $display("==========================================================");
    $display(" CHECKPOINT 5: DFT MUX & AXI Interface Verification");
    $display("==========================================================");

    // 2. AXI Register Read/Write Test
    $display("[TB] Testing AXI Write/Read to SLV_REG0...");
    axi_write(6'h00, 32'hdead_beef);
    axi_read (6'h00, read_data);
    
    if (read_data == 32'hdead_beef) begin
      $display("  [PASS] AXI Write/Read SLV_REG0: 0x%08x", read_data);
    end else begin
      $display("  [FAIL] AXI Write/Read SLV_REG0: Expected 0xdead_beef, Got 0x%08x", read_data);
    end

    // 3. DFT MUX with real CFO (0.05 Rsym)
    $display("[TB] Testing DFT MUX with real CFO (0.05 Rsym)...");
    start_of_burst = 1'b1;
    
    for (int i = 0; i < NUM_SYMS; i++) begin
      phase = 2.0 * 3.1415926535 * CFO_FREQ * i;
      
      s_axis_tdata_re = $rtoi(AMPLITUDE * $cos(phase));
      s_axis_tdata_im = $rtoi(AMPLITUDE * $sin(phase));
      s_axis_tvalid   = 1'b1;
      
      @(posedge clk);
      
      while (!s_axis_tready) begin
        @(posedge clk);
      end
    end
    
    s_axis_tvalid = 1'b0;

    // Wait for CORDIC to finish processing
    repeat (100) @(posedge clk);

    // End the burst
    start_of_burst = 1'b0;
    #10;

    // Walk through the DFT MUX select
    dft_sel = 4'd0; #10;
    $display("  dft_sel=0 -> dft_obs_data = 0x%08x (CFO EST)", dft_obs_data);
    
    dft_sel = 4'd1; #10;
    $display("  dft_sel=1 -> dft_obs_data = 0x%08x (CFO VALID)", dft_obs_data);
    
    dft_sel = 4'd2; #10;
    $display("  dft_sel=2 -> dft_obs_data = 0x%08x (s_axis_tdata_re)", dft_obs_data);
    
    dft_sel = 4'd3; #10;
    $display("  dft_sel=3 -> dft_obs_data = 0x%08x (s_axis_tdata_im)", dft_obs_data);
    
    dft_sel = 4'd4; #10;
    $display("  dft_sel=4 -> dft_obs_data = 0x%08x (DEFAULT)", dft_obs_data);

    // 4. AXI Read of CFO Estimate (Addr 0x04)
    $display("[TB] Testing AXI Read of CFO Estimate (Addr 0x04)...");
    axi_read(6'h04, read_data);
    $display("  AXI Read CFO (0x04) -> 0x%08x", read_data);

    // 5. Cleanup
    s_axis_tdata_re = '0;
    s_axis_tdata_im = '0;
    dft_sel         = '0;

    $display("==========================================================");
    $display(" CHECKPOINT 5 TEST COMPLETE");
    $display("==========================================================");
    
    // Close the file
    $fclose(file_handle);
    $finish;
  end

endmodule 