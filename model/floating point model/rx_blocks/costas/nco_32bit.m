function [phase_next, freq_word] = nco_32bit(phase_cur, cfo_coarse_norm, pi_out, mode_hold)
    if mode_hold
        freq_word  = cfo_coarse_norm;
        phase_next = mod(phase_cur + 2*pi*freq_word + pi, 2*pi) - pi;
    else
        freq_word  = cfo_coarse_norm + pi_out;
        phase_next = mod(phase_cur + 2*pi*freq_word + pi, 2*pi) - pi;
    end
end
