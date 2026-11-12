function [Kp, Ki, scale_factor] = compute_loop_gains(Bn_Ts, zeta, K_ted, K_nco, pipe_delay, compensate_delay)
    % COMPUTE_LOOP_GAINS  Derive second-order digital PI loop filter parameters.
    %
    % Mathematical Model:
    %   Standard continuous-to-discrete approximation for a charge-pump/type-II PLL:
    %     theta = Bn_Ts / (zeta + 1 / (4 * zeta))
    %     denom = (1 + 2*zeta*theta + theta^2) * K_ted * K_nco
    %     Kp0   = (4 * zeta * theta) / denom
    %     Ki0   = (4 * theta^2) / denom
    %
    % Loop Delay Compensation:
    %   When compensate_delay is enabled and pipe_delay > 0, excess pipeline latency
    %   causes loop bandwidth expansion and phase margin degradation. A bisection
    %   search numerically evaluates the equivalent noise bandwidth (Bn*T) of the
    %   delayed impulse response and determines an exact gain scaling factor.
    %
    % Inputs:
    %   Bn_Ts            - Normalized loop noise bandwidth (e.g., 0.010 for STR, 0.025 for Costas)
    %   zeta             - Damping factor (typically 0.707 for critical damping)
    %   K_ted            - Detector gain slope at equilibrium (Gardner TED or Costas PD)
    %   K_nco            - NCO/controller sensitivity gain (4 for Mod-1, 2*pi for Costas NCO)
    %   pipe_delay       - Total closed-loop feedback latency in symbols
    %   compensate_delay - Boolean flag enabling latency gain derating
    %
    % Outputs:
    %   Kp           - Proportional filter coefficient
    %   Ki           - Integral filter coefficient
    %   scale_factor - Delay compensation attenuation factor applied to (Kp0, Ki0)

    % Nominal continuous-equivalent discrete loop gains
    theta = Bn_Ts / (zeta + 1 / (4 * zeta));
    denom = (1 + 2 * zeta * theta + theta^2) * K_ted * K_nco;

    Kp0 = (4 * zeta * theta) / denom;
    Ki0 = (4 * theta^2) / denom;

    scale_factor = 1.0;
    if compensate_delay && pipe_delay > 0
        % Bisection search over scale factor [0.20, 1.05]
        low  = 0.20;
        high = 1.05;
        for iter = 1:28
            mid  = 0.5 * (low + high);
            bn_m = eval_delayed_bn(mid * Kp0, mid * Ki0, K_ted, K_nco, pipe_delay);
            if bn_m > Bn_Ts
                high = mid;
            else
                low  = mid;
            end
        end
        scale_factor = 0.5 * (low + high);
    end

    Kp = scale_factor * Kp0;
    Ki = scale_factor * Ki0;
end

function Bn_T = eval_delayed_bn(Kp, Ki, K_ted, K_nco, pipe_delay)
    N      = 2500;
    h      = zeros(N, 1);
    int_st = 0.0;
    theta  = 0.0;
    fifo   = zeros(max(pipe_delay, 1), 1);
    for k = 1:N
        phi   = double(k == 1);
        h(k)  = theta;
        e_raw = K_ted * (phi - theta);
        e_del = fifo(1);
        fifo  = [fifo(2:end); e_raw];
        int_st = int_st + Ki * e_del;
        v_pi   = Kp * e_del + int_st;
        theta  = theta + K_nco * v_pi;
        if abs(theta) > 1e6
            Bn_T = Inf;
            return;
        end
    end
    Bn_T = 0.5 * sum(h.^2);
end
