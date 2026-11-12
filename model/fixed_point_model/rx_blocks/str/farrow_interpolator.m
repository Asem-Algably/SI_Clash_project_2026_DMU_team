function y = farrow_interpolator(buf4, mu, in_scale)
    % FARROW_INTERPOLATOR  Piecewise-Parabolic Farrow Interpolator via Horner's Rule.
    %
    % Mathematical Derivation (alpha = 0.5):
    %   The continuous-time reconstructed sample at fractional offset mu in [0, 1) is:
    %     y(mu) = v2*mu^2 + v1*mu + v0 = (v2*mu + v1)*mu + v0
    %   where the 4-tap symmetric parabolic filter impulse response gives:
    %     v2 = 0.5 * (d - c - b + a)
    %     v1 = -0.5*d + 1.5*c - 0.5*b - 0.5*a
    %     v0 = b
    %   with input sample window: buf4 = [a, b, c, d] = [x[n-1], x[n], x[n+1], x[n+2]]
    %   where 'b' is the basepoint sample and mu is the fractional delay from 'b'.
    %
    % Hardware Register Sizing & Headroom:
    %   - v1, v2 intermediate registers: 16-bit sQ3.12 ([-8, +8) headroom, max |v1| <= 3.0)
    %   - Horner MAC accumulator acc1:   17-bit sQ3.13 intermediate stage
    %   - Output symbol y:               16-bit sQ1.14 ([-2, +2) headroom, max <= 1.25)
    %
    % Inputs:
    %   buf4     - 4-sample vector [a, b, c, d] (oldest to newest)
    %   mu       - Fractional interpolation interval in [0, 1)
    %   in_scale - Front-end scaling factor (0.5 for /2 input scaling)
    %
    % Outputs:
    %   y - Complex interpolated symbol at fractional interval mu

    % Saturation limits scaled by front-end in_scale (0.5 when wrapper >>1 is active)
    v_max = 8.0 * in_scale; % Q4.12 internal headroom (+3 MSB over Q1.x)
    y_max = 2.0 * in_scale; % Q2.14 output headroom   (+1 MSB over Q1.x)

    a = buf4(1);
    b = buf4(2);
    c = buf4(3);
    d = buf4(4);

    % 4-Tap Piecewise-Parabolic Farrow coefficients (alpha = 0.5)
    v2 = sat_cplx(0.5 * (d - c - b + a), v_max);
    v1 = sat_cplx(-0.5*d + 1.5*c - 0.5*b - 0.5*a, v_max);
    v0 = b;

    % Degree-2 Horner's Rule MAC execution
    acc1 = sat_cplx(v2 * mu + v1, v_max);
    y    = sat_cplx(acc1 * mu + v0, y_max);
end

function z = sat_cplx(x, lim)
    % Symmetrical complex saturation to [-lim, +lim] per axis
    re = min(max(real(x), -lim), lim);
    im = min(max(imag(x), -lim), lim);
    z  = re + 1j * im;
end
