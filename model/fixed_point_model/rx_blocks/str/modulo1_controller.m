function [M_next, strobe, mu, mid_strobe, mu_mid] = modulo1_controller(M, W, mu_bits, mu_mode, W_nom)
    % MODULO1_CONTROLLER  Two-Region Decrementing Modulo-1 Timing Controller (str.md Section 3).
    %
    % Mathematical Model:
    %   On every valid input sample: M_next = mod(M - W, 1.0)
    %   The counter range [0, 1.0) is partitioned into two regions:
    %     - Current region : [0.75, 1.0) U [0.0, 0.25)
    %     - Mid region     : [0.25, 0.75)
    %
    % Strobe & Fractional Interval (mu) Calculation:
    %   - Current Strobe: Fires when M transitions from Mid region to Current region
    %     (crosses 0.25 boundary downward). Distance above boundary is eta_cur = M - 0.25.
    %   - Mid Strobe: Fires when M transitions from Current region to Mid region
    %     (crosses 0.75 boundary downward). Distance is eta_mid = M - 0.75 (or M + 0.25 if wrapped).
    %   - Hardware Linear Approximation (mu_mode = 'linear'):
    %     mu ~= 4*eta - 16*eta*pi (1st order Taylor expansion of eta / (0.25 + pi))
    %
    % Inputs:
    %   M       - Current modulo-1 counter phase in [0, 1.0)
    %   W       - Step decrement per sample (nominal 0.25 + loop filter correction pi)
    %   mu_bits - Quantization word length for mu (10 bits per R.110)
    %   mu_mode - Division mode ('linear' for RTL shift-add or 'exact' for true division)
    %   W_nom   - Nominal decrement step (0.25 for 4 samples/symbol)
    %
    % Outputs:
    %   M_next     - Updated phase value in [0, 1.0)
    %   strobe     - Current symbol strobe (delayed to trigger TED and symbol output)
    %   mu         - Fractional delay for current strobe
    %   mid_strobe - Mid-symbol strobe (delayed to sample half-symbol for Gardner TED)
    %   mu_mid     - Fractional delay for mid strobe

    pi_val = W - W_nom;
    if strcmpi(mu_mode, 'linear')
        % RTL linear approximation: mu = 4*eta - 16*eta*pi = eta * (4 - 16*pi)
        inv_w = (1 / W_nom) - pi_val / (W_nom^2);
    else
        inv_w = 1 / W;
    end

    % Determine current region of M (before decrement)
    in_mid_old = (M >= 0.25) && (M < 0.75);

    % Decrement modulo-1 counter (WRAPPING)
    M_raw  = M - W;
    M_next = mod(M_raw, 1.0);

    % Determine next region of M_next (after decrement)
    in_mid_new = (M_next >= 0.25) && (M_next < 0.75);

    strobe     = false;
    mid_strobe = false;
    mu         = 0.0;
    mu_mid     = 0.0;

    if in_mid_old && ~in_mid_new
        % Crossed 0.25 from Mid region into Current region
        strobe  = true;
        eta_cur = M - 0.25;
        mu      = min(max(eta_cur * inv_w, 0.0), 1.0);
    elseif ~in_mid_old && in_mid_new
        % Crossed 0.75 from Current region into Mid region
        % If M was in [0, 0.25) and wrapped around 0 into [0.25, 0.75),
        % the distance above the 0.75 boundary is (M + 1.0) - 0.75 = M + 0.25.
        mid_strobe = true;
        if M >= 0.75
            eta_mid = M - 0.75;
        else
            eta_mid = M + 0.25;
        end
        mu_mid = min(max(eta_mid * inv_w, 0.0), 1.0);
    end

    if mu_bits > 0
        scale  = 2^mu_bits;
        mu     = min(floor(mu * scale) / scale, 1 - 1/scale);
        mu_mid = min(floor(mu_mid * scale) / scale, 1 - 1/scale);
    end
end
