function e_phase = costas_phase_detector(y_sym, a_ref)
    % COSTAS_PHASE_DETECTOR  Decision-directed phase error detector:
    %   e = Im{y * conj(a)} = y_Q * a_I - y_I * a_Q
    %
    % Operating Principle:
    %   For a phase error phi near zero:
    %     y ~= a * exp(j*phi) ~= a * (1 + j*phi)
    %     e ~= |a|^2 * sin(phi) ~= |a|^2 * phi
    %   Detector gain K_ted equals the average constellation power Es.
    %
    % Inputs:
    %   y_sym   - Received complex symbol after derotation
    %   a_ref   - Hard-decision reference point (slicer output or preamble symbol)
    %
    % Outputs:
    %   e_phase - Phase error scalar

    e_phase = imag(y_sym) * real(a_ref) - real(y_sym) * imag(a_ref);
end
