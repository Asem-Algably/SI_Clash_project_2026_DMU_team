function [eta_next, strobe, mu, mid_strobe, mu_mid] = modulo1_controller(eta, W, mu_bits)
    strobe     = false;
    mid_strobe = false;
    mu         = 0.0;
    mu_mid     = 0.0;

    if eta < W
        strobe   = true;
        mu       = min(max(eta / W, 0.0), 1.0);
        eta_next = eta - W + 1.0;
    else
        eta_next = eta - W;
    end

    if (eta >= 0.5) && (eta < (0.5 + W))
        mid_strobe = true;
        mu_mid     = min(max((eta - 0.5) / W, 0.0), 1.0);
    end

    if nargin >= 3 && mu_bits > 0
        scale  = 2^mu_bits;
        mu     = min(floor(mu * scale) / scale, 1 - 1/scale);
        mu_mid = min(floor(mu_mid * scale) / scale, 1 - 1/scale);
    end
end
