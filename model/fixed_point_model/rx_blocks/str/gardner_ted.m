function e_ted = gardner_ted(y_cur, y_prev, y_mid)
    % GARDNER_TED  Non-data-aided Gardner Timing Error Detector [R.108].
    %
    % Mathematical Formulation:
    %   e = Re{y_mid} * (Re{y_cur} - Re{y_prev}) + Im{y_mid} * (Im{y_cur} - Im{y_prev})
    %
    % Operating Principle:
    %   Requires 2 samples per symbol: the on-time sample y_cur, the previous on-time
    %   sample y_prev, and the half-symbol mid-point sample y_mid. The detector produces
    %   zero average error when sampling at the eye opening and a linear error slope
    %   proportional to timing offset tau.
    %
    % Inputs:
    %   y_cur  - Current interpolated on-time symbol
    %   y_prev - Preceding interpolated on-time symbol
    %   y_mid  - Intermediate mid-point sample (halfway between symbols)
    %
    % Outputs:
    %   e_ted  - Timing error scalar

    e_ted = real(y_mid) * (real(y_cur) - real(y_prev)) + ...
            imag(y_mid) * (imag(y_cur) - imag(y_prev));
end
