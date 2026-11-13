%% Acceptance Test T2, A5, Fix 4.1 & Fix 5: Loop Bandwidth, Delay Compensation & STR Slope
cur_file = mfilename('fullpath');
if ~isempty(cur_file)
    search_dir = fileparts(cur_file);
else
    search_dir = pwd;
end
for depth = 1:4
    if exist(fullfile(search_dir, 'setup_project.m'), 'file')
        addpath(search_dir);
        break;
    end
    search_dir = fileparts(search_dir);
end
setup_project(false);

disp('=== 1. Costas Linear Loop Check (K_ted = 1.0, K_nco = 2*pi, d = 0, d = 1 uncomp, d = 1 comp) ===');
disp(sprintf('%-6s | %-6s | %-16s | %-6s | %-16s | %-6s | %-6s | %-16s | %-6s | %-7s', ...
    'zeta', 'Target', 'd=0 BnT (Err%)', 'd=0 St', 'd=1 Unc (Err%)', 'd=1 St', 'Scale', 'd=1 Comp (Err%)', 'OS(%)', 'PM(deg)'));
disp(repmat('-', 1, 118));

zetas = [0.5, 0.707, 1.0];
bns   = [0.02, 0.03, 0.05];

for z = 1:numel(zetas)
    for b = 1:numel(bns)
        [Kp0, Ki0] = compute_loop_gains(bns(b), zetas(z), 1.0, 2*pi, 0, false);
        [bn_0, ~]  = sim_linear_loop(Kp0, Ki0, 1.0, 2*pi, 0);
        [bn_1u, ~] = sim_linear_loop(Kp0, Ki0, 1.0, 2*pi, 1);
        err_0  = 100 * (bn_0  - bns(b)) / bns(b);
        err_1u = 100 * (bn_1u - bns(b)) / bns(b);
        st_0   = 'PASS'; if abs(err_0)  > 10.0, st_0  = 'FAIL'; end
        st_1u  = 'PASS'; if abs(err_1u) > 10.0, st_1u = 'FAIL'; end

        [Kpc, Kic, sc] = compute_loop_gains(bns(b), zetas(z), 1.0, 2*pi, 1, true);
        [bn_1c, os_1c] = sim_linear_loop(Kpc, Kic, 1.0, 2*pi, 1);
        err_1c = 100 * (bn_1c - bns(b)) / bns(b);
        pm_1c  = compute_pm_deg(Kpc, Kic, 1.0, 2*pi, 1);

        disp(sprintf('%-6.3f | %-6.3f | %.4f (%+5.1f%%) | [%s] | %.4f (%+5.1f%%) | [%s] | %-6.4f | %.4f (%+5.1f%%) | %-6.1f | %-7.1f', ...
            zetas(z), bns(b), bn_0, err_0, st_0, bn_1u, err_1u, st_1u, sc, bn_1c, err_1c, os_1c, pm_1c));
    end
end

disp(' ');
disp('=== 2. Costas Pipe Delay Sweep (Bn_Ts = 0.025, zeta = 0.707, pipe_delay = 0..3, uncompensated) ===');
[Kp_d, Ki_d] = compute_loop_gains(0.025, 0.707, 1.0, 2*pi, 0, false);
for d = 0:3
    [bn_d, os_d] = sim_linear_loop(Kp_d, Ki_d, 1.0, 2*pi, d);
    err_d = 100 * (bn_d - 0.025) / 0.025;
    st_d  = 'PASS'; if abs(err_d) > 10.0, st_d = 'FAIL'; end
    disp(sprintf('pipe_delay = %d | Measured Bn*T = %.5f (%+.2f%%) | Overshoot = %.2f%% | [%s]', ...
        d, bn_d, err_d, os_d, st_d));
end

disp(' ');
disp('=== 3. Fix 4.1: STR Linear Model & Open-Loop Gardner TED Slope Measurement on Real Model ===');
[Kp_s, Ki_s] = compute_loop_gains(0.015, 0.707, 2.7, 4.0, 0, false);
[bn_s, os_s] = sim_linear_loop(Kp_s, Ki_s, 2.7, 4.0, 0);
disp(sprintf('STR Linear Model (Nominal K_ted = 2.70): Bn*T = %.5f (%+.2f%%), Overshoot = %.2f%%', ...
    bn_s, 100*(bn_s - 0.015)/0.015, os_s));

cfg_m = get_default_config();
cfg_m.snr_dB = Inf; cfg_m.cfo_norm = 0; cfg_m.phase_offset = 0;
cfg_m.str.open_loop = true; cfg_m.str.mu_bits = 0;

sig_labels = {'Random QPSK', 'Random 16-QAM', 'Preamble (Phase A/B)'};
for s_idx = 1:3
    if s_idx == 1
        syms_in = generate_payload(0, 3000, 42);
    elseif s_idx == 2
        syms_in = generate_payload(1, 3000, 42);
    else
        pre_full = generate_preamble('q4q2_q1', 268, []);
        syms_in  = pre_full(1:min(260, numel(pre_full)));
    end
    tx_w = pulse_shape_rrc(syms_in, cfg_m.rrc_alpha, cfg_m.rrc_span, cfg_m.sps, 'tx');
    e_pair = zeros(1, 2);
    dts = [-0.01, 0.01];
    for k_dt = 1:2
        cfg_m.tau_offset = 0.25 + dts(k_dt);
        rx_w  = apply_channel_impairments(tx_w, cfg_m);
        res_m = run_str_subsystem(rx_w, cfg_m);
        e_pair(k_dt) = mean(res_m.ted_log(21:end-20));
    end
    K_ted_meas = -(e_pair(2) - e_pair(1)) / 0.02;
    [bn_eff, os_eff] = sim_linear_loop(Kp_s, Ki_s, K_ted_meas, 4.0, 0);
    disp(sprintf('  %-22s | Measured K_ted = %6.4f | Effective Bn*T = %.5f | Overshoot = %.2f%%', ...
        sig_labels{s_idx}, K_ted_meas, bn_eff, os_eff));
end

function [Bn_T, overshoot_pct] = sim_linear_loop(Kp, Ki, K_ted, K_nco, pipe_delay)
    N = 4000;
    h = zeros(N, 1);
    int_st = 0; theta = 0;
    fifo = zeros(max(pipe_delay, 1), 1);
    for k = 1:N
        phi = double(k == 1);
        h(k) = theta;
        e_raw = K_ted * (phi - theta);
        if pipe_delay > 0
            e_del = fifo(1);
            fifo  = [fifo(2:end); e_raw];
        else
            e_del = e_raw;
        end
        [v_pi, int_st] = pi_loop_filter(e_del, int_st, Kp, Ki, Inf);
        theta = theta + K_nco * v_pi;
    end
    Bn_T = 0.5 * sum(h.^2);

    y_step = zeros(N, 1);
    int_st = 0; theta = 0;
    fifo = zeros(max(pipe_delay, 1), 1);
    for k = 1:N
        y_step(k) = theta;
        e_raw = K_ted * (1.0 - theta);
        if pipe_delay > 0
            e_del = fifo(1);
            fifo  = [fifo(2:end); e_raw];
        else
            e_del = e_raw;
        end
        [v_pi, int_st] = pi_loop_filter(e_del, int_st, Kp, Ki, Inf);
        theta = theta + K_nco * v_pi;
    end
    overshoot_pct = 100 * (max(y_step) - 1.0);
end

function pm_deg = compute_pm_deg(Kp, Ki, K_ted, K_nco, pipe_delay)
    w   = linspace(1e-5, pi, 10000).';
    z   = exp(1j * w);
    C_z = Kp + Ki ./ (1 - z.^(-1));
    N_z = K_nco .* (z.^(-1)) ./ (1 - z.^(-1));
    D_z = z.^(-pipe_delay);
    L_z = K_ted .* D_z .* C_z .* N_z;
    [~, idx] = min(abs(abs(L_z) - 1.0));
    pm_deg = 180 + angle(L_z(idx)) * (180 / pi);
    if pm_deg > 180, pm_deg = pm_deg - 360; end
end
