function y = farrow_interpolator(buf4, mu, cfg)
    % Farrow Polynomial Interpolator evaluated via Horner's Rule [R.109]
    % Supports 'cubic' (default, 4-point Lagrange cubic) and 'parabolic'
    % (piecewise-parabolic alpha = 0.5, Erup, Gardner, Harris 1993).
    %
    % Inputs:
    %   buf4 : 4-element vector [a; b; c; d] ordered oldest (n-3) to newest (n).
    %          Interpolates between basepoint b (at mu = 0) and c (at mu = 1).
    %   mu   : Fractional interpolation interval in [0, 1).
    %   cfg  : (Optional) Configuration struct (cfg or cfg.str) or mode string
    %          ('cubic' or 'parabolic'). Defaults to 'cubic' if omitted.

    interp_mode = 'cubic';
    if nargin >= 3 && ~isempty(cfg)
        if isstruct(cfg)
            if isfield(cfg, 'str') && isstruct(cfg.str) && isfield(cfg.str, 'interp_type')
                interp_mode = cfg.str.interp_type;
            elseif isfield(cfg, 'interp_type')
                interp_mode = cfg.interp_type;
            end
        elseif ischar(cfg) || isstring(cfg)
            interp_mode = char(cfg);
        end
    end

    a = buf4(1);
    b = buf4(2);
    c = buf4(3);
    d = buf4(4);

    switch lower(strtrim(interp_mode))
        case 'cubic'
            % 4-Tap Cubic Lagrange Farrow coefficients
            v3 = (1/6)*(d - a) + 0.5*(b - c);
            v2 = 0.5*(c + a) - b;
            v1 = -(1/6)*d + c - 0.5*b - (1/3)*a;
            v0 = b;

            % Degree-3 Horner's Rule (3 cascaded multiply-accumulate stages)
            y = ((v3 * mu + v2) * mu + v1) * mu + v0;

        case 'parabolic'
            % 4-Tap Piecewise-Parabolic Farrow coefficients (alpha = 0.5)
            v2 = 0.5 * (d - c - b + a);
            v1 = -0.5*d + 1.5*c - 0.5*b - 0.5*a;
            v0 = b;

            % Degree-2 Horner's Rule (2 cascaded multiply-accumulate stages)
            y = (v2 * mu + v1) * mu + v0;

        otherwise
            error('Unsupported Farrow interpolation mode: %s. Choose ''cubic'' or ''parabolic''.', interp_mode);
    end
end
