function cfg = get_default_config(schedule_mode)
    % Master configuration struct for the Si-CLASH Floating-Point Golden Model.
    % Includes Open Question switches (Q-a, Q-b, Q-c) and Part 0..4 parameters.
    % Note: DFT observation mux and force registers have been removed.
    % Note (Fix 7.4): cfg.costas.preamble_slicer = 'qpsk' indicates that the hardware
    % requires a preamble-mode slicer override driven by the symbol counter (k <= N_preamble).

    if nargin < 1 || isempty(schedule_mode)
        schedule_mode = 'default';
    end

    % --- Open Questions (Q-a, Q-b, Q-c) & Part 0 Normalisation Switches ---
    cfg.norm_mode      = 'peak';             % [0a / Q-c] 'peak' (interim default) or 'rms'
    cfg.snr_def        = 'sample';             % [1b / Q-a] 'esn0' (symbol-rate Es/N0) or 'sample' (oversampled SNR)
    cfg.evm_norm_mode  = 'rms';              % [2b / Q-b] 'rms' or 'peak' (both are printed in report)
    cfg.input_headroom = 0.22;               % [0c / Q-c] Fixed design headroom before Q1.11 quantiser (0 clips)
    cfg.output_scale   = 0.50;               % [0f] Fixed output scaling before Q1.15 quantiser (undone in EVM)
    cfg.quantize_q11   = true;               % [0c] Quantise synchroniser input to signed 12-bit Q1.11
    cfg.quantize_q15   = true;               % [0f] Quantise synchroniser output to signed 16-bit Q1.15

    % --- System & Clock Parameters (R.101 - R.107) ---
    cfg.F_clk          = 125e6;              % System clock (Hz) [R.101]
    cfg.sps            = 4;                  % Oversampling factor Ns [R.102]
    cfg.R_sym          = cfg.F_clk / cfg.sps;% 31.25 MSps symbol rate [R.103]
    cfg.mod_type       = 0;                  % 0 = QPSK, 1 = 16-QAM [R.107]
    cfg.rrc_alpha      = 0.35;               % RRC roll-off factor [CP6]
    cfg.rrc_span       = 10;                 % Filter span in symbols

    % --- Burst Frame & Three-Phase Preamble Structure (Part B1 & Part 3) ---
    cfg.schedule       = schedule_mode;      % 'default'
    cfg.preamble_type  = 'q4q2_q1';          % Default: 'q4q2_q1' ('period2', 'zadoff_chu', 'barker', 'pn')
    cfg.preamble.N_A   = 208;                % Phase A: alternating Q4/Q2 for STR + Coarse CFO
    cfg.preamble.N_B   = 60;                 % Phase B: alternating Q4/Q2 for Costas pull-in
    cfg.preamble.N_C   = 48;                 % Phase C: [Q2, Q4, Q1, Q4] for quadrant check (Q3 = 0%)
    cfg.N_preamble     = cfg.preamble.N_A + cfg.preamble.N_B + cfg.preamble.N_C; % 316 symbols
    cfg.N_payload      = 1200;               % Payload symbols (>= 1000 for CP6)
    cfg.seed           = 42;                 % RNG seed for reproducibility

    % --- Channel Impairments ---
    cfg.snr_dB         = 18.0;               % Requested SNR / Es/N0 (dB)
    cfg.tau_offset     = 0.35;               % Fractional timing delay [0, 1) Ts [CP2]
    cfg.cfo_norm       = 0.065;              % Normalized CFO (f_offset / R_sym) [R.113]
    cfg.phase_offset   = 25 * (pi/180);      % Initial carrier phase (rad)

    % --- Symbol Timing Recovery (STR) Settings (R.108 - R.112, Part 0d & Part 4a) ---
    cfg.str.interp_type     = 'cubic';       % Farrow mode: 'cubic' (default) or 'parabolic' [R.109]
    cfg.str.zeta            = 0.707;         % Damping factor
    cfg.str.Bn_Ts           = 0.015;         % Normalized loop noise bandwidth (Bn * Ts)
    cfg.str.Kp_ted          = 2.7;           % Nominal detector S-curve slope
    cfg.str.gain_sched      = true;          % Part 0d: use measured slopes at adopted norm_mode scale
    cfg.str.Kp_ted_preamble = 12.9543;       % Measured open-loop Gardner slope on preamble ('peak')
    cfg.str.Kp_ted_qpsk     = 2.1541;        % Measured open-loop Gardner slope on QPSK ('peak')
    cfg.str.Kp_ted_16qam    = 1.2326;        % Measured open-loop Gardner slope on 16-QAM ('peak')
    cfg.str.K_nco           = 4.0;           % Modulo-1 counter steps 4x per symbol
    cfg.str.W_nom           = 1 / cfg.sps;   % Nominal step = 0.25
    cfg.str.mu_bits         = 10;            % 0 = ideal float, or 8/10/12 bits [R.110]
    cfg.str.max_v_pi        = 0.035;         % Part 4a/4b: Hardware safety limit on |W - 0.25| (0 saturations)
    cfg.str.open_loop       = false;         % Open-loop S-curve calibration flag (holds W = W_nom)

    % --- Coarse CFO Estimator Settings (R.113 - R.116) ---
    cfg.coarse.tap_point       = 'interpolator'; % 'interpolator' or 'derotator'
    cfg.coarse.mode            = 'dual';     % 'dual' (lags 2 & 8) or 'single4' (lag 4)
    cfg.coarse.win_len         = 64;         % Correlation window length (32/64/128) [R.116]
    cfg.coarse.lag_short       = 2;          % Short lag D1 = 2 (unambiguous +-0.25 Rsym)
    cfg.coarse.lag_long        = 8;          % Long lag D2 = 8 (unambiguous +-0.0625 Rsym)
    cfg.coarse.angle_mode      = 'atan2';    % 'atan2' (float) or 'bisection' (hardware)
    cfg.coarse.data_aided      = false;      % Blind correlation (no reference wipe-off)
    cfg.coarse.fixed_start_sym = 0;          % 0 = wait for STR lock; >0 = start at fixed symbol

    % --- Costas Fine Carrier Loop Settings (R.118 - R.124 & Part 4a) ---
    cfg.costas.zeta             = 0.707;     % Critically damped [R.123]
    cfg.costas.Bn_Ts            = 0.025;     % Loop noise BW (0.02 - 0.05) [R.124]
    cfg.costas.Kp_ted           = 1.0;       % Nominal phase detector gain (scaled by Es in top-level)
    cfg.costas.K_nco            = 2 * pi;    % NCO advances by 2*pi*freq_word rad/symbol
    cfg.costas.derot_mode       = 'ideal';   % 'ideal' exp(-j*theta) or 'lut'
    cfg.costas.pipe_delay       = 1;         % Derotator + slicer delay in symbols (FIFO depth)
    cfg.costas.compensate_delay = true;      % Scale (Kp, Ki) so delayed Bn*T matches target
    cfg.costas.preamble_slicer  = 'qpsk';    % QPSK slicer override for k <= N_preamble
    cfg.costas.max_v_pi         = 0.12;      % Part 4a/4b: Hardware safety limit on fine frequency offset

    % --- Quadrant Ambiguity Check Settings (Part B3) ---
    cfg.quad.enable        = true;           % Enable Phase C quadrant counter & correction
    cfg.quad.skip          = 4;              % Skip first 4 symbols of Phase C window
    cfg.quad.min_ratio     = 0.25;           % Require min_count <= min_ratio * max_count

    % --- Dynamic Lock Detector Thresholds ---
    cfg.lock.str_ema_alpha      = 0.08;
    cfg.lock.str_var_thresh     = 0.05;      % Innovation variance threshold
    cfg.lock.str_confirm_cnt    = 20;        % Leaky-bucket target count (< 150 syms)
    cfg.lock.costas_ema_alpha   = 0.08;
    cfg.lock.costas_var_thresh  = 0.025;     % Phase error variance threshold
    cfg.lock.costas_confirm_cnt = 20;        % Leaky-bucket target count (< 200 syms)
end
