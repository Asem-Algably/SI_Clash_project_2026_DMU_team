function [sig_out, h_rrc] = pulse_shape_rrc(sig_in, alpha, span, sps, mode)
    % PULSE_SHAPE_RRC  Root-Raised Cosine (RRC) pulse shaping and matched filtering.
    %
    % Mathematical Model:
    %   Generates normalized unit-energy RRC impulse response with roll-off factor alpha.
    %   - 'tx' mode: Upsamples input symbols by factor sps with zeros, scales by sqrt(sps),
    %                and convolves with h_rrc.
    %   - 'rx' mode: Convolves input oversampled samples with matched filter h_rrc / sqrt(sps).
    %
    % Inputs:
    %   sig_in - Input signal (symbols for 'tx', oversampled samples for 'rx')
    %   alpha  - RRC excess bandwidth roll-off factor (typically 0.35 per CP6)
    %   span   - Filter span in symbol periods
    %   sps    - Samples per symbol (oversampling factor = 4)
    %   mode   - Operation mode ('tx' or 'rx')
    %
    % Outputs:
    %   sig_out - Filtered output signal
    %   h_rrc   - Computed unit-energy filter coefficients

    sig_in = sig_in(:);
    t = (-span*sps/2 : span*sps/2).' / sps;
    h_rrc = zeros(size(t));
    for i = 1:numel(t)
        ti = t(i);
        if abs(ti) < 1e-12
            h_rrc(i) = 1 - alpha + (4*alpha/pi);
        elseif abs(abs(ti) - 1/(4*alpha)) < 1e-9
            h_rrc(i) = (alpha/sqrt(2)) * ((1 + 2/pi)*sin(pi/(4*alpha)) + (1 - 2/pi)*cos(pi/(4*alpha)));
        else
            num = sin(pi*ti*(1 - alpha)) + 4*alpha*ti*cos(pi*ti*(1 + alpha));
            den = pi*ti*(1 - (4*alpha*ti)^2);
            h_rrc(i) = num / den;
        end
    end
    h_rrc = h_rrc / sqrt(sum(h_rrc.^2));

    if strcmpi(mode, 'tx')
        up_sig = zeros(numel(sig_in) * sps, 1);
        up_sig(1:sps:end) = sig_in * sqrt(sps);
        sig_out = conv(up_sig, h_rrc, 'same');
    elseif strcmpi(mode, 'rx')
        sig_out = conv(sig_in, h_rrc / sqrt(sps), 'same');
    else
        error('Mode must be tx or rx.');
    end
end
