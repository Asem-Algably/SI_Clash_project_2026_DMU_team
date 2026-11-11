function [M_next, strobe, mu, mid_strobe, mu_mid] = modulo1_controller(M, W, mu_bits, mu_mode, W_nom)
    % Modulo-1 counter M, decremented by W every input sample (matches str.md Section 3.5).
    % Regions:
    %   Current region : [0.75, 1.0) U [0.0, 0.25)
    %   Mid region     : [0.25, 0.75)
    % Strobes fire on region boundary crossings:
    %   current strobe : M enters Current region from Mid region (crosses 0.25 downward)
    %   mid strobe     : M enters Mid region from Current region (crosses 0.75 downward)
    if nargin < 4 || isempty(mu_mode), mu_mode = 'linear'; end
    if nargin < 5 || isempty(W_nom),   W_nom   = 0.25;     end

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

    if nargin >= 3 && mu_bits > 0
        scale  = 2^mu_bits;
        mu     = min(floor(mu * scale) / scale, 1 - 1/scale);
        mu_mid = min(floor(mu_mid * scale) / scale, 1 - 1/scale);
    end
end
