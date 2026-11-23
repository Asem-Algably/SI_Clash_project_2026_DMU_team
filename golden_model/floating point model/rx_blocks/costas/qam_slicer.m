function a_hat = qam_slicer(y_sym, mod_type, norm_mode)
    % Part 0b: Derives all slicer thresholds (0 and +-thresh_2d) and decision levels
    % strictly from get_constellation_map(mod_type, norm_mode). No hard-coded thresholds.
    if nargin < 3 || isempty(norm_mode)
        norm_mode = 'peak';
    end
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
