function cfg = get_default_config(schedule_mode)
    % Master configuration struct for the Si-CLASH Unified Golden Model.
    % Supports:
    %   - cfg.exec_mode  = 'fixed_cycle' | 'float_cycle' | 'float_symbol'
    %   - All hardware bit-widths (cfg.fxp.w) and register latencies (cfg.fxp.lat)
    if nargin < 1 || isempty(schedule_mode)
        schedule_mode = 'default';
    end

    % --- Execution Mode Switch ---
    % 'fixed_cycle'  : Clock-accurate, interface-accurate fixed-point (fi) model
    % 'float_cycle'  : Clock-accurate, interface-accurate double-precision model (debug)
    % 'float_symbol' : Fast symbol-rate floating-point model
    cfg.exec_mode        = 'fixed_cycle';

    % --- Open Questions (Q-a, Q-b, Q-c) & Wrapper +1 MSB (>>1) Scaling ---
    cfg.norm_mode        = 'peak';           % 'peak' (default) or 'rms'
    cfg.snr_def          = 'sample';         % 'esn0' or 'sample'
    cfg.evm_norm_mode    = 'rms';            % 'rms' or 'peak'
    cfg.wrapper_shift_en = true;             % Right-shift input by 1 (/2, +1 MSB pad) at wrapper in, left-shift by 1 (*2) at wrapper out
    cfg.in_scale         = 0.5;              % >>1 input scale (0.5 = +1 MSB headroom)
    cfg.quantize_q11     = true;             % Q1.11 input quantizer (after wrapper shift)
    cfg.quantize_q15     = true;             % Q1.15 output quantizer (before display shift)

    % --- System & Clock Parameters (R.101 - R.107) ---
    cfg.F_clk          = 125e6;              % System clock (Hz) [R.101]
    cfg.sps            = 4;                  % Oversampling factor Ns [R.102]
    cfg.R_sym          = cfg.F_clk / cfg.sps;% 31.25 MSps symbol rate [R.103]
    cfg.mod_type       = 0;                  % 0 = QPSK, 1 = 16-QAM [R.107]
    cfg.rrc_alpha      = 0.35;               % RRC roll-off factor [CP6]
    cfg.rrc_span       = 10;                 % Filter span in symbols

    % --- Burst Frame & Three-Phase Preamble Structure ---
    cfg.schedule       = schedule_mode;
    cfg.preamble_type  = 'q4q2_q1';          % Phase C uses [Q1, Q2, Q4, Q1]
    cfg.preamble.N_A   = 96;                 % Phase A: alternating Q4/Q2 for STR + Coarse CFO
    cfg.preamble.N_B   = 48;                 % Phase B: alternating Q4/Q2 for Costas pull-in
    cfg.preamble.N_C   = 40;                 % Phase C: [Q1, Q2, Q4, Q1] for quadrant check (Q3 = 0%)
    cfg.N_preamble     = cfg.preamble.N_A + cfg.preamble.N_B + cfg.preamble.N_C; % 184 symbols
    cfg.N_payload      = 1200;               % Payload symbols (>= 1000 for CP6)
    cfg.seed           = 42;                 % RNG seed for reproducibility

    % --- Channel Impairments ---
    cfg.snr_dB         = 18.0;               % Requested SNR / Es/N0 (dB)
    cfg.tau_offset     = 0.35;               % Fractional timing delay [0, 1) Ts [CP2]
    cfg.cfo_norm       = 0.065;              % Normalized CFO (f_offset / R_sym) [R.113]
    cfg.phase_offset   = 25 * (pi/180);      % Initial carrier phase (rad)

    % --- Symbol Timing Recovery (STR) Settings (str.md) ---
    cfg.str.interp_type     = 'parabolic';   % Parabolic Farrow [R.109]
    cfg.str.zeta            = 0.707;         % Damping factor
    cfg.str.Bn_Ts           = 0.015;         % Normalized loop noise bandwidth (matches float model)
    cfg.str.Kp_ted          = 2.1541;        % Fixed nominal detector slope
    cfg.str.gain_sched      = false;         % Hardware STR ignores burst FSM (single fixed gain pair)
    cfg.str.Kp_ted_preamble = 12.9543;       % Reference slope for lock detector normalization
    cfg.str.Kp_ted_qpsk     = 2.1541;
    cfg.str.Kp_ted_16qam    = 1.2326;
    cfg.str.K_nco           = 4.0;           % Modulo-1 counter steps 4x per symbol
    cfg.str.W_nom           = 1 / cfg.sps;   % Nominal step = 0.25
    cfg.str.mu_bits         = 10;            % 10-bit mu [R.110]
    cfg.str.mu_mode         = 'linear';      % 'linear' mu = (4 - 16*pi)*eta (RTL form)
    cfg.str.max_v_pi        = 0.035;         % Saturation limit on |W - 0.25|
    cfg.str.open_loop       = false;

    % --- Coarse CFO Estimator Settings (coarse_cfo.md) ---
    cfg.coarse.tap_point       = 'interpolator';
    cfg.coarse.mode            = 'single4';  % Single lag D=4
    cfg.coarse.win_len         = 32;         % 32-symbol window [R.116: 32..128 sym]
    cfg.coarse.lag_short       = 2;
    cfg.coarse.lag_long        = 8;
    cfg.coarse.angle_mode      = 'cordic';   % 'cordic' (16-iter vectoring) or 'atan2'
    cfg.coarse.cordic_iter     = 16;         % CORDIC vectoring iterations
    cfg.coarse.data_aided      = false;
    cfg.coarse.fixed_start_sym = 0;

    % --- Costas Fine Carrier Loop Settings (costas.md & derotator.md) ---
    cfg.costas.zeta             = 0.707;     % Critically damped [R.123]
    cfg.costas.Bn_Ts            = 0.025;     % Loop noise BW [R.124] (matches float model)
    cfg.costas.Kp_ted           = 1.0;       % Unitless trim factor
    cfg.costas.K_nco            = 2 * pi;    % NCO gain
    cfg.costas.derot_mode       = 'lut';     % Quarter-wave LUT (derotator.md)
    cfg.costas.lut_addr_bits    = 12;        % 12 address bits
    cfg.costas.pipe_delay       = 1;         % Loop pipeline delay in symbols
    cfg.costas.compensate_delay = true;      % Delay compensation enabled
    cfg.costas.preamble_slicer  = 'qpsk';    % Force QPSK slicer during preamble (slicer_qpsk_i)
    cfg.costas.max_v_pi         = 0.12;      % Saturation limit on PI filter output

    % --- Quadrant Ambiguity Check Settings (costas.md 5-bit sign counters) ---
    cfg.quad.enable        = true;

    % --- Dynamic Lock Detector Thresholds ---
    cfg.lock.ema_shift          = 4;         % m <- m + (|e| - m) * 2^-4
    cfg.lock.str_thr_enter      = 0.060;     % STR enter threshold
    cfg.lock.str_thr_exit       = 0.150;     % STR exit threshold (hysteresis holds lock across payload)
    cfg.lock.str_m0             = 0.30;
    cfg.lock.str_confirm_cnt    = 20;
    cfg.lock.costas_thr_enter   = 0.200;
    cfg.lock.costas_thr_exit    = 0.300;
    cfg.lock.costas_m0          = 0.35;
    cfg.lock.costas_confirm_cnt = 12;

    % --- Fixed-Point & Cycle-Accurate Hardware Parameters ---
    cfg.fxp.round_default = 'Floor';         % Default register assignment rounding ('Floor' = truncation)
    cfg.fxp.lat.str       = 4;               % Lumped STR Farrow interpolator pipeline latency (clocks)
    cfg.fxp.lat.coarse    = 12;              % Coarse CFO CORDIC latency after window end (clocks, coarse_cfo.md)
    cfg.fxp.lat.derot     = 2;               % Derotator LUT + complex multiplier latency (clocks, derotator.md)
    cfg.fxp.lat.costas    = 1;               % Costas error + PI filter register latency (clocks)
    cfg.fxp.lat.wrap_out  = 1;               % Wrapper output register stage (clocks)

    % Word-length table: [Signed, WordLength, FractionLength]
    % Scaled for >>1 (in_scale = 0.5) with +1 MSB on symbol busses and +3 MSB on Farrow internals
    cfg.fxp.w.in      = [1, 12, 11];         % Input port Q1.11 (represents Q2.10 with >>1 shift) [R.104]
    cfg.fxp.w.str_sym = [1, 16, 14];         % STR output symbol Q2.14 (range [-2, +2))
    cfg.fxp.w.fv      = [1, 16, 12];         % Farrow internal v1, v2, v3 registers Q4.12 (range [-8, +8))
    cfg.fxp.w.fh      = [1, 16, 13];         % Farrow Horner intermediate stages Q3.13 (range [-4, +4))
    cfg.fxp.w.fk      = [0, 18, 17];         % Cubic Farrow constants (1/6, 1/3)
    cfg.fxp.w.M       = [0, 24, 24];         % Modulo-1 counter M and step W (unsigned fraction, WRAPS)
    cfg.fxp.w.M_s     = [1, 25, 24];         % Modulo-1 signed difference wire (M - W, M - 0.25, M - 0.75)
    cfg.fxp.w.eta     = [0, 18, 18];         % Distance above strobe boundary
    cfg.fxp.w.pi_mu   = [1, 18, 17];         % PI filter output feeding mu linear multiplier
    cfg.fxp.w.mu      = [0, 10, 10];         % Fractional interval mu (10-bit unsigned) [R.110]
    cfg.fxp.w.ted_d   = [1, 17, 14];         % Gardner TED difference (cur - prev)
    cfg.fxp.w.ted_e   = [1, 25, 21];         % Gardner TED error output
    cfg.fxp.w.str_pi  = [1, 26, 28];         % STR PI integrator and output
    cfg.fxp.w.str_kp  = [0, 24, 24];         % STR proportional gain Kp
    cfg.fxp.w.str_ki  = [0, 24, 30];         % STR integral gain Ki
    cfg.fxp.w.cprod   = [1, 22, 19];         % Coarse CFO r[n]*conj(r[n-4]) product
    cfg.fxp.w.cacc    = [1, 28, 21];         % Coarse CFO correlation accumulator (range [-64, +64))
    cfg.fxp.w.cx      = [1, 30, 22];         % CORDIC vectoring X, Y registers
    cfg.fxp.w.cz      = [1, 28, 26];         % CORDIC angle Z accumulator (in turns)
    cfg.fxp.w.cfo     = [1, 24, 24];         % Coarse CFO output port (24-bit signed turns/symbol)
    cfg.fxp.w.lut     = [0, 16, 16];         % Quarter-wave sine LUT entry (16-bit unsigned)
    cfg.fxp.w.phase   = [0, 32, 32];         % 32-bit NCO phase accumulator in binary radians (WRAPS) [R.120]
    cfg.fxp.w.freq_w  = [1, 32, 32];         % 32-bit NCO frequency word in turns/symbol
    cfg.fxp.w.rot_out = [1, 16, 15];         % Derotator & Wrapper output symbol Q1.15 (represents Q2.14 before <<1) [R.105]
    cfg.fxp.w.cos_a   = [1, 16, 14];         % Costas slicer decision level
    cfg.fxp.w.cos_e   = [1, 22, 19];         % Costas phase detector error
    cfg.fxp.w.cos_pi  = [1, 27, 28];         % Costas PI integrator and output
    cfg.fxp.w.cos_kp  = [0, 24, 22];         % Costas proportional gain Kp
    cfg.fxp.w.cos_ki  = [0, 24, 29];         % Costas integral gain Ki
    cfg.fxp.w.sgn_cnt = [1,  5,  0];         % 5-bit signed saturating quadrant counters (-16..+15)
    cfg.fxp.w.cnt     = [0, 16,  0];         % 16-bit unsigned symbol counter (saturating)
    cfg.fxp.w.lock_m  = [1, 23, 18];         % Lock detector EMA register (signed to support a - m_old in fi)
    cfg.fxp.w.lock_b  = [0,  8,  0];         % Lock detector leaky bucket counter
end
