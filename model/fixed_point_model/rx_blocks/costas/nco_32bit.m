function [phase_next, freq_word] = nco_32bit(phase_cur, cfo_coarse_norm, pi_out, mode_hold)
    % NCO_32BIT  Phase accumulator for carrier frequency and phase tracking [R.120].
    %
    % Mathematical Model:
    %   freq_word  = cfo_coarse_norm + (mode_hold ? 0 : pi_out)
    %   phase_next = mod(phase_cur + 2*pi*freq_word + pi, 2*pi) - pi
    %
    % Hardware Precision:
    %   In RTL, this is a 32-bit wrapping phase accumulator:
    %   theta[31:0] <= theta[31:0] + freq_word[31:0]
    %   where 2^32 corresponds to one complete turn (2*pi radians).
    %
    % Inputs:
    %   phase_cur       - Current carrier phase angle in radians [-pi, +pi)
    %   cfo_coarse_norm - Normalized coarse frequency offset estimate (turns/symbol)
    %   pi_out          - Costas PI loop filter frequency adjustment
    %   mode_hold       - Boolean flag; when true, freezes fine carrier updates
    %
    % Outputs:
    %   phase_next      - Updated carrier phase in radians [-pi, +pi)
    %   freq_word       - Total active normalized frequency word (turns/symbol)

    if mode_hold
        freq_word  = cfo_coarse_norm;
    else
        freq_word  = cfo_coarse_norm + pi_out;
    end
    phase_next = mod(phase_cur + 2*pi*freq_word + pi, 2*pi) - pi;
end
