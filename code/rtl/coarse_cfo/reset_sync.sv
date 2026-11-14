////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         A reset_sync module.
// Date:           6-11-2026
// Description:    reset for top module.
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////



module reset_sync (
    input  logic clk_i,    // Destination clock
    input  logic rst_ni,   // Async reset input, active low
    output logic rst_no    // Sync reset output, active low
  );

    logic rst_n_meta_q;    // Metastability flipflop output

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rst_n_meta_q <= 1'b0;  // Async assert
        rst_no       <= 1'b0;  // Async assert
      end else begin
        rst_n_meta_q <= 1'b1;  // Deassert through meta flop
        rst_no       <= rst_n_meta_q;  // Deassert one cycle later
      end
    end

endmodule
