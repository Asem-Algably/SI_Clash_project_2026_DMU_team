function y_derot = derotator(x_sym, phase_rad, mode)
    if nargin < 3 || strcmpi(mode, 'ideal')
        y_derot = x_sym * exp(-1j * phase_rad);
    else
        N_lut = 4096;
        idx   = mod(round(phase_rad / (2*pi) * N_lut), N_lut);
        q_ang = (idx + 0.5) * (2*pi / N_lut);
        c_val = cos(q_ang);
        s_val = sin(q_ang);
        y_derot = (real(x_sym)*c_val + imag(x_sym)*s_val) + ...
               1j*(imag(x_sym)*c_val - real(x_sym)*s_val);
    end
end
