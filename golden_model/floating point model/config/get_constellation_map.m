function const = get_constellation_map(mod_type, norm_mode)
    % Part 0a & 0b: Single source of truth for constellation scale and 16-QAM slicer thresholds.
    % - 'peak' (default): largest per-axis symbol level is 1.
    %     QPSK   = +-1 per axis (d = 1, Es = 2).
    %     16-QAM = +-1/3 and +-1 per axis (d = 1/3, thresh_2d = 2/3, Es = 10/9).
    % - 'rms': unit average power (Es = 1).
    %     QPSK   = +-1/sqrt(2) per axis (d = 1/sqrt(2), Es = 1).
    %     16-QAM = +-1/sqrt(10) and +-3/sqrt(10) per axis (d = 1/sqrt(10), thresh_2d = 2/sqrt(10), Es = 1).

    if nargin < 2 || isempty(norm_mode)
        norm_mode = 'peak';
    elseif isstruct(norm_mode) && isfield(norm_mode, 'norm_mode')
        norm_mode = norm_mode.norm_mode;
    end

    switch lower(strtrim(char(norm_mode)))
        case 'peak'
            if mod_type == 0
                d = 1.0;
            else
                d = 1.0 / 3.0;
            end
        case 'rms'
            if mod_type == 0
                d = 1.0 / sqrt(2.0);
            else
                d = 1.0 / sqrt(10.0);
            end
        otherwise
            error('Unsupported norm_mode: %s. Choose ''peak'' or ''rms''.', char(norm_mode));
    end

    if mod_type == 0
        const.name      = 'QPSK';
        const.M         = 4;
        const.d         = d;
        const.thresh_2d = 0.0;
        pts_1d          = [-d, d];
    else
        const.name      = '16-QAM';
        const.M         = 16;
        const.d         = d;
        const.thresh_2d = 2.0 * d; % 2/3 for 'peak', 2/sqrt(10) for 'rms'
        pts_1d          = [-3.0*d, -d, d, 3.0*d];
    end

    [I_grid, Q_grid] = meshgrid(pts_1d, pts_1d);
    const.norm_mode  = lower(strtrim(char(norm_mode)));
    const.symbols    = I_grid(:) + 1j * Q_grid(:);
    const.avg_power  = mean(abs(const.symbols).^2);
    const.rms_power  = sqrt(const.avg_power);
    const.peak_power = max(abs(const.symbols));
    const.peak_axis  = max(abs(pts_1d));
end
