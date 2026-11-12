function a_hat = qam_slicer(y_sym, mod_type, norm_mode)
    % QAM_SLICER  Decision-directed slicer for QPSK and 16-QAM constellations.
    % Derives all slicer thresholds (0 and +-thresh_2d) and decision levels
    % strictly from get_constellation_map(mod_type, norm_mode).
    %
    % Inputs:
    %   y_sym     - Received derotated complex symbol
    %   mod_type  - Modulation format selector (0 = QPSK, 1 = 16-QAM)
    %   norm_mode - Constellation normalization convention ('peak' or 'rms')
    %
    % Outputs:
    %   a_hat     - Hard-decision sliced constellation point

    const = get_constellation_map(mod_type, norm_mode);
    d     = const.d;
    t_2d  = const.thresh_2d;

    if mod_type == 0
        a_I = d * sign(real(y_sym));
        a_Q = d * sign(imag(y_sym));
        if a_I == 0, a_I = d; end
        if a_Q == 0, a_Q = d; end
    else
        a_I = slice_4pam(real(y_sym), d, t_2d);
        a_Q = slice_4pam(imag(y_sym), d, t_2d);
    end
    a_hat = a_I + 1j * a_Q;
end

function val = slice_4pam(x, d, thresh_2d)
    if x >= thresh_2d
        val = 3 * d;
    elseif x >= 0
        val = d;
    elseif x >= -thresh_2d
        val = -d;
    else
        val = -3 * d;
    end
end
