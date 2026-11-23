function e_ted = gardner_ted(y_cur, y_prev, y_mid)
    % Non-data-aided Gardner Timing Error Detector
    e_ted = real(y_mid) * (real(y_cur) - real(y_prev)) + ...
            imag(y_mid) * (imag(y_cur) - imag(y_prev));
end
