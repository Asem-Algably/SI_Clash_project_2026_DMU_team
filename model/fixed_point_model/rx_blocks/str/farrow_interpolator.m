function y = farrow_interpolator(buf4, mu, cfg, in_scale)
    % Farrow Polynomial Interpolator evaluated via Horner's Rule [R.109]
    % Supports 'parabolic' (default per str.md) and 'cubic'.
    % Includes internal hardware MSB padding saturation bounds:
    %   - Internal v1, v2 registers: [-8, +8) unscaled ([-4, +4) with >>1 input shift, Q4.12)
    %   - Output y register:         [-2, +2) unscaled ([-1, +1) with >>1 input shift, Q2.14)

    interp_mode = 'parabolic';
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
    if nargin < 4 || isempty(in_scale)
        in_scale = 1.0;
    end

    % Hardware saturation limits scaled by in_scale (0.5 when wrapper >>1 is active)
    v_max = 8.0 * in_scale; % Q4.12 internal headroom (+3 MSB over Q1.x)
    y_max = 2.0 * in_scale; % Q2.14 output headroom   (+1 MSB over Q1.x)

    a = buf4(1);
    b = buf4(2);
    c = buf4(3);
    d = buf4(4);

    switch lower(strtrim(interp_mode))
        case 'parabolic'
            % 4-Tap Piecewise-Parabolic Farrow coefficients (alpha = 0.5)
            v2 = sat_cplx(0.5 * (d - c - b + a), v_max);
            v1 = sat_cplx(-0.5*d + 1.5*c - 0.5*b - 0.5*a, v_max);
            v0 = b;

            % Degree-2 Horner's Rule
            acc1 = sat_cplx(v2 * mu + v1, v_max);
            y    = sat_cplx(acc1 * mu + v0, y_max);

        case 'cubic'
            % 4-Tap Cubic Lagrange Farrow coefficients
            v3 = sat_cplx((1/6)*(d - a) + 0.5*(b - c), v_max);
            v2 = sat_cplx(0.5*(c + a) - b, v_max);
            v1 = sat_cplx(-(1/6)*d + c - 0.5*b - (1/3)*a, v_max);
            v0 = b;

            % Degree-3 Horner's Rule
            y = sat_cplx(((v3 * mu + v2) * mu + v1) * mu + v0, y_max);

        otherwise
            error('Unsupported Farrow interpolation mode: %s. Choose ''parabolic'' or ''cubic''.', interp_mode);
    end
end

function z = sat_cplx(x, lim)
    re = min(max(real(x), -lim), lim);
    im = min(max(imag(x), -lim), lim);
    z  = re + 1j * im;
end
