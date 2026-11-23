function [Kp, Ki, scale_factor] = compute_loop_gains(Bn_Ts, zeta, K_ted, K_nco, pipe_delay, compensate_delay)
    % Computes 2nd-order digital PI loop filter gains directly from Bn_Ts and zeta
    % without external loop_gain[7:0] or costas_loop_gain[7:0] ports.
    % When compensate_delay is true and pipe_delay > 0 (Fix 5.2), scales (Kp, Ki)
    % via bisection on the delayed linear loop impulse response so Bn*T matches Bn_Ts.
    if nargin < 5 || isempty(pipe_delay),       pipe_delay = 0;          end
    if nargin < 6 || isempty(compensate_delay), compensate_delay = false; end

    theta = Bn_Ts / (zeta + 1 / (4 * zeta));
    denom = (1 + 2 * zeta * theta + theta^2) * K_ted * K_nco;

    Kp0 = (4 * zeta * theta) / denom;
    Ki0 = (4 * theta^2) / denom;

    scale_factor = 1.0;
    if compensate_delay && pipe_delay > 0
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
