function y_derot = derotator(x_sym, phase_rad, mode, addr_bits)
    % y = x * exp(-j*theta).
    % mode 'ideal': exact complex exponential.
    % mode 'lut'  : quarter-wave method from docs/modules/derotator.md.
    %   theta (turns) -> top 2 bits = quadrant q, next addr_bits = address a (truncated).
    %   One quarter-wave sine table with midpoint sampling  S[a] = sin((a + 0.5)*(pi/2)/Nq).
    %   s0 = S[a], c0 = S[Nq-1-a] (cosine from the complementary address).
    %   Pre-rotate x' = x*(-j)^q, then y = x' * (c0 - j*s0):
    %     q=0: x' = ( xr,  xi)   q=1: x' = ( xi, -xr)   q=2: x' = (-xr, -xi)   q=3: x' = (-xi,  xr)
    %     y_re = x'_re*c0 + x'_im*s0 ;  y_im = x'_im*c0 - x'_re*s0
    if nargin < 3 || strcmpi(mode, 'ideal')
        y_derot = x_sym * exp(-1j * phase_rad);
        return;
    end
    if nargin < 4 || isempty(addr_bits), addr_bits = 12; end
    Nq    = 2^addr_bits;
    turns = phase_rad / (2*pi);
    turns = turns - floor(turns);                       % [0, 1)
    t4    = turns * 4;
    q     = min(floor(t4), 3);
    a     = min(floor((t4 - q) * Nq), Nq - 1);          % truncate
    d     = (pi/2) / Nq;
    s0    = sin((a + 0.5) * d);
    c0    = sin((Nq - 1 - a + 0.5) * d);
    xr = real(x_sym); xi = imag(x_sym);
    switch q
        case 0, pr =  xr; pi_ =  xi;
        case 1, pr =  xi; pi_ = -xr;
        case 2, pr = -xr; pi_ = -xi;
        otherwise, pr = -xi; pi_ = xr;
    end
    y_derot = (pr*c0 + pi_*s0) + 1j*(pi_*c0 - pr*s0);
end
