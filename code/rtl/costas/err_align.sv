////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         err_align
// Date:           13-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////



// Error alignment shift registers. Delays the STR TED error and the Costas
// phase error so they can be observed in the same cycle as the symbol they
// The exact delay values depend on the block latencies
// must be confirmed by open issue Error alignment lengths

//   StrDelay    = number of clock cycles to delay the STR TED error
//                 so it aligns with the derotator output.
//   CostasDelay = number of clock cycles to delay the Costas error.
//                 Set to 0 if no alignment is needed (pass-through).
//
// A value of 0 selects a pure bypass (no register, no latency).

module err_align #(
  parameter int unsigned StrDelay    = 2,
  parameter int unsigned CostasDelay = 0,
  parameter int unsigned TedWidth    = 32,
  parameter int unsigned CostasWidth = 16
) (
  input  logic                            clk_i,
  input  logic                            rst_ni,

  // STR TED error
  input  logic signed [TedWidth-1:0]      ted_err_i,
  input  logic                            ted_err_valid_i,

  // Costas phase error
  input  logic signed [CostasWidth-1:0]   costas_err_i,
  input  logic                            costas_err_valid_i,

  // Aligned outputs
  output logic signed [TedWidth-1:0]      ted_err_o,
  output logic                            ted_err_valid_o,
  output logic signed [CostasWidth-1:0]   costas_err_o,
  output logic                            costas_err_valid_o
);

  // --------------------------------------------------------------------------
  // STR TED error delay line
  // --------------------------------------------------------------------------
  generate
    if (StrDelay == 0) begin : g_ted_bypass
      assign ted_err_o       = ted_err_i;
      assign ted_err_valid_o = ted_err_valid_i;
    end else begin : g_ted_delay
      logic signed [TedWidth-1:0] ted_err_pipe [StrDelay];
      logic                       ted_vld_pipe [StrDelay];

      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          for (int unsigned i = 0; i < StrDelay; i++) begin
            ted_err_pipe[i] <= '0;
            ted_vld_pipe[i] <= 1'b0;
          end
        end else begin
          ted_err_pipe[0] <= ted_err_i;
          ted_vld_pipe[0] <= ted_err_valid_i;
          for (int unsigned i = 1; i < StrDelay; i++) begin
            ted_err_pipe[i] <= ted_err_pipe[i-1];
            ted_vld_pipe[i] <= ted_vld_pipe[i-1];
          end
        end
      end

      assign ted_err_o       = ted_err_pipe[StrDelay-1];
      assign ted_err_valid_o = ted_vld_pipe[StrDelay-1];
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Costas phase error delay line
  // --------------------------------------------------------------------------
  generate
    if (CostasDelay == 0) begin : g_costas_bypass
      assign costas_err_o       = costas_err_i;
      assign costas_err_valid_o = costas_err_valid_i;
    end else begin : g_costas_delay
      logic signed [CostasWidth-1:0] costas_err_pipe [CostasDelay];
      logic                          costas_vld_pipe [CostasDelay];

      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          for (int unsigned i = 0; i < CostasDelay; i++) begin
            costas_err_pipe[i] <= '0;
            costas_vld_pipe[i] <= 1'b0;
          end
        end else begin
          costas_err_pipe[0] <= costas_err_i;
          costas_vld_pipe[0] <= costas_err_valid_i;
          for (int unsigned i = 1; i < CostasDelay; i++) begin
            costas_err_pipe[i] <= costas_err_pipe[i-1];
            costas_vld_pipe[i] <= costas_vld_pipe[i-1];
          end
        end
      end

      assign costas_err_o       = costas_err_pipe[CostasDelay-1];
      assign costas_err_valid_o = costas_vld_pipe[CostasDelay-1];
    end
  endgenerate

endmodule