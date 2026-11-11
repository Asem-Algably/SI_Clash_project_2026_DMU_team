function [Kp, Ki, Bn_Ts, zeta, scale_factor] = decode_gain_ports(~, default_Bn, default_zeta, K_ted, K_nco, pipe_delay, compensate_delay)
    % Pass-through wrapper: ignores external 8-bit gain port and computes Kp, Ki
    % directly from configured default_Bn and default_zeta, including delay compensation.
    if nargin < 6 || isempty(pipe_delay),       pipe_delay = 0;          end
    if nargin < 7 || isempty(compensate_delay), compensate_delay = false; end

    Bn_Ts = default_Bn;
    zeta  = default_zeta;
    [Kp, Ki, scale_factor] = compute_loop_gains(Bn_Ts, zeta, K_ted, K_nco, pipe_delay, compensate_delay);
end
