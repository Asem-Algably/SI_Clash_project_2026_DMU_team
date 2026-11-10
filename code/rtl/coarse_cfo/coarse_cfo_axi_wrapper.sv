////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A coarse_cfo_axi_wrapper module.
// Date: 8-11-2026
// Description: AXI4-Lite wrapper for the coarse CFO estimator
////////////////////////////////////////////////////////////////////////////////

module coarse_cfo_axi_wrapper #(
    parameter int unsigned CSlvAxiDataWidth = 32,  // AXI data width
    parameter int unsigned CSlvAxiAddrWidth = 6    // AXI address width
  ) (
    input  logic s00_axi_aclk,                        // AXI clock
    input  logic s00_axi_aresetn,                     // AXI reset, active low
    input  logic [CSlvAxiAddrWidth-1:0] s00_axi_awaddr,   // Write addr
    input  logic [2:0]                  s00_axi_awprot,   // Write prot
    input  logic                        s00_axi_awvalid,  // Write addr valid
    output logic                        s00_axi_awready,  // Write addr ready
    input  logic [CSlvAxiDataWidth-1:0]     s00_axi_wdata, // Write data
    input  logic [(CSlvAxiDataWidth/8)-1:0] s00_axi_wstrb, // Write strobes
    input  logic                            s00_axi_wvalid, // Write data valid
    output logic                            s00_axi_wready, // Write data ready
    output logic [1:0] s00_axi_bresp,                 // Write response
    output logic       s00_axi_bvalid,                // Write resp valid
    input  logic       s00_axi_bready,                // Write resp ready
    input  logic [CSlvAxiAddrWidth-1:0] s00_axi_araddr, // Read addr
    input  logic [2:0]                  s00_axi_arprot, // Read prot
    input  logic                        s00_axi_arvalid,// Read addr valid
    output logic                        s00_axi_arready,// Read addr ready
    output logic [CSlvAxiDataWidth-1:0] s00_axi_rdata,  // Read data
    output logic [1:0]                  s00_axi_rresp,  // Read response
    output logic                        s00_axi_rvalid, // Read data valid
    input  logic                        s00_axi_rready, // Read data ready
    input  logic signed [15:0] s_axis_tdata_re,         // I symbol in
    input  logic signed [15:0] s_axis_tdata_im,         // Q symbol in
    input  logic               s_axis_tvalid,           // Symbol strobe
    output logic               s_axis_tready,           // Accept symbol
    input  logic               start_of_burst,          // Burst active
    output logic signed [23:0] m_axis_cfo_est,          // Estimate out
    output logic               m_axis_tvalid,           // Estimate valid
    input  logic [3:0]  dft_sel,                        // DFT mux select
    output logic [31:0] dft_obs_data                    // DFT observation
  );

    // Synchronize the reset
    logic rst_n_sync;  // Synchronized reset

    reset_sync u_reset_sync (
      .clk_i (s00_axi_aclk),     // AXI clock
      .rst_ni(s00_axi_aresetn),  // AXI reset
      .rst_no(rst_n_sync)        // Synchronized reset
    );

    // Coarse CFO core interface
    logic signed [23:0] cfo_est;   // Estimate from core
    logic               cfo_valid; // Valid from core

    // There is no ready on the core; accept while burst active
    assign s_axis_tready = start_of_burst;

    coarse_cfo_core #(
      .DataWidth(16),    // 16-bit symbols
      .Lag      (4),     // Lag 4
      .WinLen   (64)     // 64 symbols
    ) u_coarse_cfo_core (
      .clk_i           (s00_axi_aclk),        // Clock
      .rst_ni          (rst_n_sync),          // Reset
      .start_i         (start_of_burst),      // Start on burst
      .s_axis_valid_i  (s_axis_tvalid),       // Symbol strobe
      .s_axis_i_sym_i  (s_axis_tdata_re),     // I symbol
      .s_axis_q_sym_i  (s_axis_tdata_im),     // Q symbol
      .m_axis_valid_o  (cfo_valid),           // Estimate valid
      .m_axis_cfo_o    (cfo_est),             // Estimate
      .force_cfo_en_i  (1'b0),                // Force disabled (TODO)
      .force_cfo_i     (24'sd0)               // Force value unused
    );

    assign m_axis_cfo_est = cfo_est;    // Route to AXI out
    assign m_axis_tvalid  = cfo_valid;  // Route to AXI out

    // DFT observation mux
    always_comb begin
      unique case (dft_sel)
        4'd0:    dft_obs_data = {8'b0, cfo_est};         // Observe CFO estimate
        4'd1:    dft_obs_data = {31'b0, cfo_valid};      // Observe valid
        4'd2:    dft_obs_data = {16'b0, s_axis_tdata_re};// Observe I symbol
        4'd3:    dft_obs_data = {16'b0, s_axis_tdata_im};// Observe Q symbol
        default: dft_obs_data = 32'hdead_beef;           // Default pattern
      endcase
    end

    // Silence unused AXI inputs
    logic unused_signals;
    assign unused_signals = ^{s00_axi_awprot, s00_axi_wstrb, s00_axi_arprot};

    // AXI4-Lite write channel registers
    logic                        aw_ready_q;  // AWREADY reg
    logic                        w_ready_q;   // WREADY reg
    logic                        b_valid_q;   // BVALID reg
    logic [1:0]                  b_resp_q;    // BRESP reg
    logic [CSlvAxiDataWidth-1:0] slv_reg0_q;  // Register 0

    always_ff @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
      if (!s00_axi_aresetn) begin
        aw_ready_q <= 1'b0;         // Reset
        w_ready_q  <= 1'b0;         // Reset
        b_valid_q  <= 1'b0;         // Reset
        b_resp_q   <= 2'b00;        // OKAY
        slv_reg0_q <= '0;           // Reset
      end else begin
        if (!aw_ready_q && s00_axi_awvalid && s00_axi_wvalid) begin
          aw_ready_q <= 1'b1;       // Accept write
          w_ready_q  <= 1'b1;       // Accept data
          b_valid_q  <= 1'b1;       // Send response
          if (s00_axi_awaddr[3:2] == 2'b00) begin
            slv_reg0_q <= s00_axi_wdata;  // Write to reg 0
          end
        end else begin
          aw_ready_q <= 1'b0;       // Single-cycle accept
          w_ready_q  <= 1'b0;       // Single-cycle accept
        end
        if (b_valid_q && s00_axi_bready) begin
          b_valid_q <= 1'b0;        // Handshake complete
        end
      end
    end

    assign s00_axi_awready = aw_ready_q;   // Drive AWREADY
    assign s00_axi_wready  = w_ready_q;    // Drive WREADY
    assign s00_axi_bvalid  = b_valid_q;    // Drive BVALID
    assign s00_axi_bresp   = b_resp_q;     // Drive BRESP

    // AXI4-Lite read channel registers
    logic                        ar_ready_q;  // ARREADY reg
    logic                        r_valid_q;   // RVALID reg
    logic [CSlvAxiDataWidth-1:0] r_data_q;    // RDATA reg
    logic [1:0]                  r_resp_q;    // RRESP reg

    always_ff @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
      if (!s00_axi_aresetn) begin
        ar_ready_q <= 1'b0;         // Reset
        r_valid_q  <= 1'b0;         // Reset
        r_data_q   <= '0;           // Reset
        r_resp_q   <= 2'b00;        // OKAY
      end else begin
        if (!ar_ready_q && s00_axi_arvalid) begin
          ar_ready_q <= 1'b1;       // Accept read
          r_valid_q  <= 1'b1;       // Send data
          unique case (s00_axi_araddr[3:2])
            2'b00:   r_data_q <= slv_reg0_q;              // Read reg 0
            2'b01:   r_data_q <= {8'b0, cfo_valid, cfo_est}; // Read CFO
            default: r_data_q <= 32'hdead_beef;           // Default pattern
          endcase
        end else begin
          ar_ready_q <= 1'b0;       // Single-cycle accept
        end
        if (r_valid_q && s00_axi_rready) begin
          r_valid_q <= 1'b0;        // Handshake complete
        end
      end
    end

    assign s00_axi_arready = ar_ready_q;   // Drive ARREADY
    assign s00_axi_rvalid  = r_valid_q;    // Drive RVALID
    assign s00_axi_rdata   = r_data_q;     // Drive RDATA
    assign s00_axi_rresp   = r_resp_q;     // Drive RRESP

endmodule 