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

  // The 4-bit selector indexes exactly 16 entries, so a direct index is
  // safe. Kept as a unique case for readability and to guard against an
  // accidental width change in NumChannels.
  always_comb begin
    unique case (dft_sel_i)
      4'd0:    dft_obs_data_o = obs_data_i[0];
      4'd1:    dft_obs_data_o = obs_data_i[1];
      4'd2:    dft_obs_data_o = obs_data_i[2];
      4'd3:    dft_obs_data_o = obs_data_i[3];
      4'd4:    dft_obs_data_o = obs_data_i[4];
      4'd5:    dft_obs_data_o = obs_data_i[5];
      4'd6:    dft_obs_data_o = obs_data_i[6];
      4'd7:    dft_obs_data_o = obs_data_i[7];
      4'd8:    dft_obs_data_o = obs_data_i[8];
      4'd9:    dft_obs_data_o = obs_data_i[9];
      4'd10:   dft_obs_data_o = obs_data_i[10];
      4'd11:   dft_obs_data_o = obs_data_i[11];
      4'd12:   dft_obs_data_o = obs_data_i[12];
      4'd13:   dft_obs_data_o = obs_data_i[13];
      4'd14:   dft_obs_data_o = obs_data_i[14];
      default: dft_obs_data_o = obs_data_i[15];
    endcase
  end

endmodule