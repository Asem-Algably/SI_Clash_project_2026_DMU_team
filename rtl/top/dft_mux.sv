////////////////////////////////////////////////////////////////////////////////
// Author:         Hadeer Ghoneim
// Design:         DFT MUX
// Date:           13-11-2026
// Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
// Organization:   Electronics Research Institute (ERI) - SI_CLASH Challenge
////////////////////////////////////////////////////////////////////////////////



// 16-channel observation MUX for the DFT test bus (Checkpoint 5).
// Selects one of 16 32-bit observation values onto dft_obs_data_o.

// Channel assignment (fixed by the top-level integration):
//   channel 0  : TED error (aligned)
//   channel 1  : STR mu
//   channel 2  : STR W (loop filter output)
//   channel 3  : STR symbol I
//   channel 4  : Coarse CFO estimate
//   channel 5  : Costas phase error (aligned)
//   channel 6  : NCO frequency word
//   channel 7  : NCO phase accumulator
//   channel 8  : Derotated symbol I
//   channel 9  : Costas loop integrator
//   channel 10 : Costas phase correction (k*pi/2 pulse)
//   channel 11 : Costas frequency correction
//   channel 12 : STR lock
//   channel 13 : Costas public lock
//   channel 14 : Burst FSM state
//   channel 15 : STR output valid (timing reference)

module dft_mux #(
  parameter int unsigned NumChannels = 16,
  parameter int unsigned DataWidth   = 32,
  parameter int unsigned DftSelWidth = 4
) (
  input  logic [DftSelWidth-1:0]               dft_sel_i,
  input  logic [NumChannels-1:0][DataWidth-1:0] obs_data_i,
  output logic [DataWidth-1:0]                 dft_obs_data_o
);

  // Index safely across parameterized NumChannels and DftSelWidth without dead branches
  generate
    if (NumChannels >= (1 << DftSelWidth)) begin : gen_full_mux
      assign dft_obs_data_o = obs_data_i[dft_sel_i];
    end else begin : gen_bounded_mux
      assign dft_obs_data_o = (dft_sel_i < DftSelWidth'(NumChannels))
                            ? obs_data_i[dft_sel_i]
                            : {DataWidth{1'b0}};
    end
  endgenerate

endmodule