function plot_sync_diagnostics(rx_out, metrics, cfg)
    % PLOT_SYNC_DIAGNOSTICS  Display 4-panel synchronizer diagnostic visualization:
    %   1. Constellation diagram (STR output vs. synced payload vs. ideal grid)
    %   2. STR tracking (mu fractional delay and Gardner TED error)
    %   3. Carrier frequency tracking (NCO frequency word vs. coarse estimate vs. true CFO)
    %   4. Fine phase lock (Costas phase detector error and top-level lock_detect status)

    const = get_constellation_map(cfg.mod_type, cfg.norm_mode);
    N_sym = numel(rx_out.out_sym_cplx);
    N_tail= max(min(1000, floor(N_sym * 0.6)), 1);
    idx_t = (N_sym - N_tail + 1) : N_sym;

    figure('Name', 'Si-CLASH Synchronizer Diagnostics', 'Color', 'w', 'Position', [100 100 1100 720]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    rx_tail = rx_out.out_sym_cplx(idx_t);
    plot(real(rx_out.str.symbols(idx_t)), imag(rx_out.str.symbols(idx_t)), '.', ...
        'Color', [0.82 0.82 0.82], 'DisplayName', 'Pre-Derotator (STR Out)'); hold on;
    plot(real(rx_tail), imag(rx_tail), 'b.', 'MarkerSize', 6, 'DisplayName', 'Synced Payload');
    plot(real(const.symbols), imag(const.symbols), 'r+', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Ideal');
    grid on; axis equal; xlim([-1.2 1.2]); ylim([-1.2 1.2]);
    title(sprintf('%s Constellation (RMS EVM = %.2f%%)', const.name, metrics.evm_rms_pct));
    xlabel('In-Phase (I)'); ylabel('Quadrature (Q)'); legend('Location', 'best');

    nexttile;
    yyaxis left;
    plot(1:N_sym, rx_out.str.mu_log, 'LineWidth', 1.2);
    ylabel('Fractional Delay \mu'); ylim([-0.05 1.05]);
    yyaxis right;
    plot(1:N_sym, rx_out.str.ted_log, 'Color', [0.85 0.33 0.10]);
    ylabel('Gardner TED Error');
    grid on;
    title(sprintf('STR Tracking (Lock @ Sym %d, Jitter = %.4f T_s)', metrics.str_lock_syms, metrics.timing_jitter_Ts));
    xlabel('Symbol Index');

    nexttile;
    plot(1:N_sym, rx_out.nco_freq_log, 'b', 'LineWidth', 1.5, 'DisplayName', 'NCO Freq Word'); hold on;
    yline(cfg.cfo_norm, 'r--', 'LineWidth', 1.5, 'DisplayName', 'True CFO');
    yline(rx_out.coarse_cfo_est, 'g:', 'LineWidth', 1.5, 'DisplayName', 'Coarse Estimate');
    grid on;
    title(sprintf('Carrier Frequency Tracking (Coarse Err = %.3f%% R_{sym})', metrics.coarse_cfo_err_pct));
    xlabel('Symbol Index'); ylabel('Normalized CFO (f / R_{sym})'); legend('Location', 'best');

    nexttile;
    yyaxis left;
    plot(1:N_sym, rx_out.costas_err, 'Color', [0.2 0.4 0.8]);
    ylabel('Costas Phase Detector Error');
    yyaxis right;
    stairs(1:N_sym, double(rx_out.lock_detect), 'r', 'LineWidth', 1.8);
    ylabel('System lock\_detect'); ylim([-0.1 1.2]);
    grid on;
    title(sprintf('Fine Phase Lock (Residual Phase RMS = %.2f deg)', metrics.phase_err_deg_rms));
    xlabel('Symbol Index');
end
