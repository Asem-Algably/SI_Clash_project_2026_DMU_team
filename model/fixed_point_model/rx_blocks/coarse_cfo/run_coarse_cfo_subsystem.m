function [cfo_est_norm, details] = run_coarse_cfo_subsystem(rx_sym_win, cfg, ref_preamble_win)
    % RUN_COARSE_CFO_SUBSYSTEM  Coarse frequency offset estimation over window of symbols.
    % Supports single lag-4 mode ('single4') or dual-lag mode ('dual').

    if exist('ref_preamble_win', 'var') == 0
        ref_preamble_win = [];
    end

    est_mode = 'dual';
    if isfield(cfg.coarse, 'mode')
        est_mode = cfg.coarse.mode;
    end

    if strcmpi(est_mode, 'single4')
        D4     = 4;
        R_4    = conj_autocorr(rx_sym_win, D4, ref_preamble_win, cfg.coarse.data_aided);
        ang_4  = angle_solver(R_4, cfg.coarse.angle_mode);
        f_4    = ang_4 / (2 * pi * D4);

        cfo_est_norm    = f_4;
        details.R_short = R_4;
        details.R_long  = R_4;
        details.f_short = f_4;
        details.f_long  = f_4;
        details.k_wrap  = 0;
    else
        D1 = cfg.coarse.lag_short;
        D2 = cfg.coarse.lag_long;

        R_short = conj_autocorr(rx_sym_win, D1, ref_preamble_win, cfg.coarse.data_aided);
        R_long  = conj_autocorr(rx_sym_win, D2, ref_preamble_win, cfg.coarse.data_aided);

        ang_short = angle_solver(R_short, cfg.coarse.angle_mode);
        ang_long  = angle_solver(R_long,  cfg.coarse.angle_mode);

        f_short = ang_short / (2 * pi * D1);
        f_long  = ang_long  / (2 * pi * D2);

        k_wrap       = round(D2 * (f_short - f_long));
        cfo_est_norm = f_long + (k_wrap / D2);

        details.R_short = R_short;
        details.R_long  = R_long;
        details.f_short = f_short;
        details.f_long  = f_long;
        details.k_wrap  = k_wrap;
    end
end
