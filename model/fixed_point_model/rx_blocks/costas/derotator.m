function y_derot = derotator(x_sym, phase_rad, mode, addr_bits)
    % DEROTATOR  Carrier phase derotation: y = x * exp(-j*theta).
    %
    % Modes:
    %   - 'ideal': Continuous double-precision complex exponential.
    %   - 'lut'  : Hardware quarter-wave sine LUT (derotator.md).
    %              Upper 2 bits of theta select quadrant q in {0,1,2,3}.
    %              Next addr_bits index the quarter-wave ROM S[a] = sin((a+0.5)*(pi/2)/Nq).
    %              Cosine obtained from complementary address c0 = S[~a].
    %              Input is pre-rotated by (-j)^q followed by complex multiplication.
    %
    % Inputs:
    %   x_sym     - Received complex symbol
    %   phase_rad - NCO carrier phase in radians
    %   mode      - 'lut' or 'ideal'
    %   addr_bits - Number of LUT address bits (default 12 -> 4096 entries)
    %
    % Outputs:
    %   y_derot   - Derotated complex symbol

    if strcmpi(mode, 'ideal')
        y_derot = x_sym * exp(-1j * phase_rad);
        return;
    end
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
