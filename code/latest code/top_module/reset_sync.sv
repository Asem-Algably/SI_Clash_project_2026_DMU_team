////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: A reset_sync module.
// Date: 13-11-2026
// Description: reset for top module.
////////////////////////////////////////////////////////////////////////////////

// Reset synchronizer: asynchronous assert, synchronous deassert.
// Output rst_no is held low while rst_ni is low, then releases
// NumStages clock cycles after rst_ni rises.
//
// Standard practice per lowRISC Verilog Coding Style Guide (Resets section)
// and "Verilog Design to Avoid for ASIC" section 6.

module reset_sync #(
  // 2 stages is sufficient for <= 200 MHz in most processes.
  // Use 3 for high-frequency ASIC targets or noisy reset sources.
  parameter int unsigned NumStages = 2
) (
  input  logic clk_i,    // Destination clock
  input  logic rst_ni,   // Async reset input, active low
  output logic rst_no    // Sync reset output, active low
);

  // Force the tools to treat these flops as a synchronizer chain
  (* async_reg = "true" *) logic [NumStages-1:0] rst_n_pipe;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rst_n_pipe <= '0;   // Async assert
    end else begin
      rst_n_pipe <= {rst_n_pipe[NumStages-2:0], 1'b1};  // Sync deassert
    end
  end

  assign rst_no = rst_n_pipe[NumStages-1];

endmodule
