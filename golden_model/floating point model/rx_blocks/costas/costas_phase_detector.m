function e_phase = costas_phase_detector(y_sym, a_ref)
    % Phase detector: e = y_Q * a_I - y_I * a_Q
    e_phase = imag(y_sym) * real(a_ref) - real(y_sym) * imag(a_ref);
end
