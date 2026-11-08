function [Kp, Ki, Bn_Ts, zeta] = decode_gain_ports(~, default_Bn, default_zeta, K_ted, K_nco)
    % Pass-through wrapper: ignores external 8-bit gain port and computes Kp, Ki
    % directly from configured default_Bn and default_zeta.
    Bn_Ts = default_Bn;
    zeta  = default_zeta;
    [Kp, Ki] = compute_loop_gains(Bn_Ts, zeta, K_ted, K_nco);
end
