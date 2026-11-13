function plot_sync_diagnostics(rx_out, metrics, cfg)
    % PLOT_SYNC_DIAGNOSTICS  Display 4-panel synchronizer diagnostic visualization:
    %   1. Constellation diagram (Pre-Derotator vs Synced Payload vs Ideal)
    %   2. STR tracking (mu fractional delay and Gardner TED error)
    %   3. Carrier frequency tracking (NCO frequency word vs coarse vs true CFO)
    %   4. Fine phase lock (Costas phase detector error and lock_detect status)

    if cfg.mod_type == 0
        const_name = 'QPSK';
        ideal_syms = [-1-1j, -1+1j, 1-1j, 1+1j].';
    else
        const_name = '16-QAM';
        pts = [-1.0, -1.0/3.0, 1.0/3.0, 1.0];
        [I, Q] = meshgrid(pts, pts);
        ideal_syms = I(:) + 1j * Q(:);
    end

    N_sym  = numel(rx_out.out_sym_cplx);
    N_tail = max(min(1000, floor(N_sym * 0.6)), 1);
    idx_t  = (N_sym - N_tail + 1) : N_sym;

    figure('Name', 'Si-CLASH Synchronizer Diagnostics', 'Color', 'w', 'Position', [100 100 1100 720]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    % Panel 1: Constellation
    nexttile;
    in_sc = 0.5;
    rx_tail  = double(rx_out.out_sym_cplx(idx_t)) / in_sc;
    str_disp = double(rx_out.str.symbols(idx_t)) / in_sc;
    plot(real(str_disp), imag(str_disp), '.', ...
        'Color', [0.82 0.82 0.82], 'DisplayName', 'STR Out (Pre-Derotator)'); hold on;
    plot(real(rx_tail), imag(rx_tail), 'b.', 'MarkerSize', 6, 'DisplayName', 'Synced Payload');
    plot(real(ideal_syms), imag(ideal_syms), 'r+', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Ideal Grid');
    grid on; axis equal; xlim([-1.4 1.4]); ylim([-1.4 1.4]);
    title(sprintf('%s Constellation (Excess EVM = %.2f%%, Total = %.2f%%)', ...
        const_name, double(metrics.evm_excess_pct), double(metrics.evm_total_pct)));
    xlabel('In-Phase (I)'); ylabel('Quadrature (Q)'); legend('Location', 'best');

    % Panel 2: STR Tracking
    nexttile;
    yyaxis left;
    plot(1:N_sym, double(rx_out.str.mu_log), 'LineWidth', 1.2);
    ylabel('Fractional Delay \mu'); ylim([-0.05 1.05]);
    yyaxis right;
    plot(1:N_sym, double(rx_out.str.ted_log), 'Color', [0.85 0.33 0.10]);
    ylabel('Gardner TED Error');
    grid on;
    title(sprintf('STR Tracking (Lock @ Sym %d)', round(metrics.str_lock_sym)));
    xlabel('Symbol Index');

    % Panel 3: Carrier Frequency Tracking
    nexttile;
    plot(1:N_sym, double(rx_out.nco_freq_log), 'b', 'LineWidth', 1.5, 'DisplayName', 'NCO Freq Word'); hold on;
    yline(cfg.cfo_norm, 'r--', 'LineWidth', 1.5, 'DisplayName', 'True CFO');
    yline(double(rx_out.coarse_cfo_est), 'g:', 'LineWidth', 1.5, 'DisplayName', 'Coarse Estimate');
    grid on;
    title(sprintf('Carrier Frequency Tracking (Error = %.4f%%)', metrics.fine_cfo_err * 100));
    xlabel('Symbol Index'); ylabel('Normalized CFO (f / R_{sym})'); legend('Location', 'best');

    % Panel 4: Costas Phase Detector & Lock Detect
    nexttile;
    yyaxis left;
    plot(1:N_sym, double(rx_out.costas_err), 'Color', [0.2 0.4 0.8]);
    ylabel('Costas Phase Detector Error');
    yyaxis right;
    stairs(1:N_sym, double(rx_out.lock_detect), 'r', 'LineWidth', 1.8);
    ylabel('System lock\_detect'); ylim([-0.1 1.2]);
    grid on;
    title(sprintf('Costas Loop Tracking (Lock @ Sym %d, SER = %.4f)', ...
        round(metrics.costas_lock_sym), double(metrics.ser)));
    xlabel('Symbol Index');
end
