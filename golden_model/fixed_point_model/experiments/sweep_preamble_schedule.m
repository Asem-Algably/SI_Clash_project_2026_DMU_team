%% Fix 6.2: Preamble Schedule Sweep Against R.122 (200 Symbols)
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

disp('=== Fix 6.2: Preamble Schedule Sweep (100 Bursts per Candidate @ True Es/N0 = 15 dB) ===');
cand_names = {'A (208,60,48 w64 dual)', 'B (144,48,48 w32 sgl4)', 'C (fix24 w32 N_C=48)', 'D (fix24 w32 N_C=16)', 'E (D + confirm=12)'};
N_bursts   = 100;

for c_idx = 1:5
    str_lck = zeros(N_bursts, 1);
    crs_don = zeros(N_bursts, 1);
    cst_stl = zeros(N_bursts, 1);
    qud_cor = zeros(N_bursts, 1);
    pub_tot = zeros(N_bursts, 1);
    pub_ld  = zeros(N_bursts, 1);
    crs_err = zeros(N_bursts, 1);
    sers    = zeros(N_bursts, 1);
    unres   = 0;
    wrong_q = 0;

    for b = 1:N_bursts
        rng(5000 + b);
        cfg = get_default_config();
        cfg.mod_type     = mod(b, 2);
        cfg.snr_dB       = 15.0;
        cfg.tau_offset   = rand();
        cfg.cfo_norm     = -0.10 + 0.20 * rand();
        cfg.phase_offset = -pi + 2 * pi * rand();

        if c_idx == 2
            cfg.preamble.N_A = 144; cfg.preamble.N_B = 48; cfg.preamble.N_C = 48;
            cfg.N_preamble = 240; cfg.coarse.mode = 'single4'; cfg.coarse.win_len = 32;
        elseif c_idx == 3
            cfg.preamble.N_A = 96; cfg.preamble.N_B = 48; cfg.preamble.N_C = 48;
            cfg.N_preamble = 192; cfg.coarse.mode = 'single4'; cfg.coarse.win_len = 32;
            cfg.coarse.fixed_start_sym = 24;
        elseif c_idx == 4
            cfg.preamble.N_A = 96; cfg.preamble.N_B = 48; cfg.preamble.N_C = 16;
            cfg.N_preamble = 160; cfg.coarse.mode = 'single4'; cfg.coarse.win_len = 32;
            cfg.coarse.fixed_start_sym = 24; cfg.quad.skip = 2;
        elseif c_idx == 5
            cfg = get_default_config('fast');
            cfg.mod_type     = mod(b, 2);
            cfg.snr_dB       = 15.0;
            cfg.tau_offset   = rand();
            cfg.cfo_norm     = -0.10 + 0.20 * rand();
            cfg.phase_offset = -pi + 2 * pi * rand();
        end

        pre = generate_preamble('q4q2_q1', cfg.N_preamble, cfg);
        pay = generate_payload(cfg.mod_type, cfg.N_payload, 6000 + b);
        tx  = pulse_shape_rrc([pre; pay], cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');
        rx  = apply_channel_impairments(tx, cfg);
        out = run_cycle_accurate_top(rx, true(size(rx)), cfg);
        met = compute_evm_and_metrics(out, pay, cfg);

        str_lck(b) = met.str_lock_syms;
        crs_don(b) = out.coarse_done_sym;
        cst_stl(b) = out.costas_settle_sym;
        qud_cor(b) = out.quad_corr_sym;
        pub_tot(b) = met.costas_lock_syms;
        pub_ld(b)  = met.costas_lock_from_load_syms;
        crs_err(b) = met.coarse_cfo_err_pct;
        sers(b)    = met.ser;
        if out.quad_unresolved, unres = unres + 1; end
        if abs(met.phase_bias_deg) > 45.0, wrong_q = wrong_q + 1; end
    end

    p95_tot = prctile_simple(pub_tot(pub_tot > 0), 95);
    p95_ld  = prctile_simple(pub_ld(pub_ld > 0), 95);
    st_r122 = 'FAIL'; if p95_tot <= 200 && wrong_q == 0, st_r122 = 'PASS'; end
    disp(sprintf('%-22s | PubLock Start: mean=%.1f, p95=%.1f | From LOAD: mean=%.1f, p95=%.1f | CFOerr=%.3f%% | Unres=%d | WrongQ=%d | MeanSER=%.4f | [%s]', ...
        cand_names{c_idx}, mean(pub_tot(pub_tot>0)), p95_tot, mean(pub_ld(pub_ld>0)), p95_ld, ...
        sqrt(mean(crs_err.^2)), unres, wrong_q, mean(sers), st_r122));
end

function val = prctile_simple(x, p)
    if isempty(x), val = NaN; return; end
    xs  = sort(x(:));
    idx = min(max(ceil((p / 100) * numel(xs)), 1), numel(xs));
    val = xs(idx);
end
