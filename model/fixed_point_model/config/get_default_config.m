function cfg = get_default_config()
    % Master configuration struct for the Si-CLASH Cycle-Accurate Fixed-Point Golden Model.
    %
    % Signal & ADC Scaling Convention:
    %   - Ideal unnormalized constellation is +-1 (QPSK, max range 2) and +-1, +-3 (16-QAM, max range 6),
    %     normalized to peak = 1.0 (+-1 for QPSK, +-1/3 & +-1 for 16-QAM).
    %   - The external ADC / front-end scales the incoming waveform by 1/2 (in_scale = 0.5) so
    %     nominal symbol levels are +-0.5 (QPSK) and +-1/6, +-0.5 (16-QAM), and clips any extreme
    %     noise spikes above [-1, 1 - 2^-11] (signed Q1.11) BEFORE entering the synchronizer.
    %   - Inside the synchronizer, all datapath registers use pure 2's-complement wrapping ('wrap')
    %     with proper MSB guard bits; saturation logic is used ONLY in the PI loop filters.

    cfg.norm_mode        = 'peak';           % 'peak' constellation normalization
    cfg.snr_def          = 'sample';         % 'sample' or 'esn0'
    cfg.evm_norm_mode    = 'rms';            % 'rms' or 'peak'
    cfg.in_scale         = 0.5;              % External ADC / front-end /2 scaling (maps [-2, +2) to [-1, +1) Q1.11)
    cfg.quantize_q11     = true;             % External ADC Q1.11 quantization & [-1, 1-2^-11] clipping

    % --- System & Clock Parameters (R.101 - R.107) ---
    cfg.F_clk            = 125e6;            % System clock (Hz) [R.101]
    cfg.sps              = 4;                % Oversampling factor Ns [R.102]
    cfg.R_sym            = cfg.F_clk / cfg.sps; % 31.25 MSps symbol rate [R.103]
    cfg.mod_type         = 1;                % 0 = QPSK, 1 = 16-QAM [R.107]
    cfg.rrc_alpha        = 0.35;             % RRC roll-off factor [CP6]
    cfg.rrc_span         = 10;               % Filter span in symbols

    % --- Burst Frame & Three-Phase Preamble Structure ---
    cfg.preamble_type    = 'q4q2_q1';        % Phase C uses [Q1, Q2, Q4, Q1]
    cfg.preamble.N_A     = 84;               % Phase A: alternating Q4/Q2 for STR + Coarse CFO
    cfg.preamble.N_B     = 40;               % Phase B: alternating Q4/Q2 for Costas pull-in
    cfg.preamble.N_C     = 40;               % Phase C: [Q1, Q2, Q4, Q1] for quadrant check
    cfg.N_preamble       = cfg.preamble.N_A + cfg.preamble.N_B + cfg.preamble.N_C; % 164 symbols
    cfg.N_payload        = 1200;             % Payload symbols (>= 1000 for CP6)
    cfg.seed             = 42;               % RNG seed for reproducibility

    % --- Channel Impairments ---
    cfg.snr_dB           = 18.0;             % Requested SNR (dB)
    cfg.tau_offset       = 0.35;             % Fractional timing delay [0, 1) Ts [CP2]
    cfg.cfo_norm         = 0.065;            % Normalized CFO (f_offset / R_sym) [R.113]
    cfg.phase_offset     = 115 * (pi/180);   % Initial carrier phase (rad)

    % --- Symbol Timing Recovery (STR) Settings (str.md) ---
    cfg.str.interp_type  = 'parabolic';      % Parabolic Farrow [R.109]
    cfg.str.zeta         = 0.707;            % Damping factor
    cfg.str.Bn_Ts        = 0.010;            % Normalized loop noise bandwidth
    cfg.str.K_nco        = 4.0;              % Modulo-1 counter steps 4x per symbol
    cfg.str.W_nom        = 1 / cfg.sps;      % Nominal step = 0.25
    cfg.str.mu_bits      = 10;               % 10 fractional bits for mu [R.110]
    cfg.str.mu_mode      = 'linear';         % 'linear' mu = 4*eta - 16*eta*pi (RTL form)
    cfg.str.max_v_pi     = 0.035;            % PI filter saturation limit on |W - 0.25|
    cfg.str.open_loop    = false;

    % --- Coarse CFO Estimator Settings (coarse_cfo.md: tapped strictly after STR) ---
    cfg.coarse.win_len         = 32;         % 32-symbol window [R.116: 32..128 sym]
    cfg.coarse.cordic_iter     = 16;         % 16-stage vectoring CORDIC
    cfg.coarse.angle_mode      = 'cordic';
    cfg.coarse.fixed_start_sym = 0;

    % --- Costas Fine Carrier Loop Settings (costas.md & derotator.md) ---
    cfg.costas.zeta             = 0.707;     % Critically damped [R.123]
    cfg.costas.Bn_Ts            = 0.025;     % Loop noise BW [R.124]
    cfg.costas.Kp_ted           = 1.0;       % Detector gain trim factor
    cfg.costas.K_nco            = 2 * pi;    % NCO gain
    cfg.costas.derot_mode       = 'lut';     % Quarter-wave LUT (derotator.md)
    cfg.costas.lut_addr_bits    = 12;        % 12 address bits (4096 entries)
    cfg.costas.pipe_delay       = 1;         % Closed-loop symbol delay
    cfg.costas.compensate_delay = true;      % Closed-loop delay compensation
    cfg.costas.max_v_pi         = 0.12;      % PI filter saturation limit

    % --- Quadrant Ambiguity Check & Lock Detector Thresholds ---
    cfg.quad.enable             = true;
    cfg.lock.ema_shift          = 4;         % m <- m + (|e| - m) >>> 4
    cfg.lock.str_thr_enter      = 0.060;
    cfg.lock.str_thr_exit       = 0.150;
    cfg.lock.str_m0             = 0.30;
    cfg.lock.str_confirm_cnt    = 20;
    cfg.lock.costas_thr_enter   = 0.200;
    cfg.lock.costas_thr_exit    = 0.300;
    cfg.lock.costas_m0          = 0.35;
    cfg.lock.costas_confirm_cnt = 12;

    % --- Fixed-Point Hardware Latencies (Clock Cycles) ---
    cfg.fxp.round_default = 'Floor';         % RTL truncation
    cfg.fxp.lat.str       = 4;               % Farrow interpolator pipeline latency
    cfg.fxp.lat.coarse    = 16;              % CORDIC pipeline latency (16 iterations in cordic_angle.sv)
    cfg.fxp.lat.derot     = 2;               % Derotator LUT + complex multiplier latency
    cfg.fxp.lat.costas    = 1;               % Costas PI filter register latency
    cfg.fxp.lat.wrap_out  = 1;               % Wrapper output register stage latency

    % --- Resized Hardware Bus Widths: [Signed, WordLength, FractionLength] ---
    % Sized with MSB guard bits so all non-PI datapath registers operate in 'wrap' mode without overflow
    cfg.fxp.w.in      = [1, 12, 11];         % sQ0.11 : ADC input port in [-1, 1 - 2^-11] [R.104]
    cfg.fxp.w.fv      = [1, 16, 12];         % sQ3.12 : Farrow v1, v2 polynomial coeffs (range [-8, +8), max |v1| <= 3.0)
    cfg.fxp.w.fh      = [1, 17, 13];         % sQ3.13 : Farrow Horner MAC intermediate stage register (v2*mu + v1)
    cfg.fxp.w.str_sym = [1, 16, 14];         % sQ1.14 : STR interpolated symbol output (range [-2, +2), max <= 1.25)
    cfg.fxp.w.M       = [0, 24, 24];         % uQ0.24 : Modulo-1 counter M and step W (wraps mod 1.0)
    cfg.fxp.w.M_s     = [1, 25, 24];         % sQ0.24 : Signed 25-bit Modulo-1 difference wire
    cfg.fxp.w.eta     = [1, 19, 18];         % sQ0.18 : Signed distance above strobe boundary
    cfg.fxp.w.pi_mu   = [1, 18, 17];         % sQ0.17 : PI filter output feeding linear mu multiplier
    cfg.fxp.w.mu      = [1, 12, 10];         % sQ1.10 : Fractional interval mu (10 frac bits [R.110] + 1 int guard bit)
    cfg.fxp.w.ted_d   = [1, 17, 14];         % sQ2.14 : Gardner TED difference (cur - prev, range [-4, +4))
    cfg.fxp.w.ted_e   = [1, 25, 21];         % sQ3.21 : Gardner TED error output (range [-8, +8))
    cfg.fxp.w.str_pi  = [1, 26, 28];         % sQ-3.28: STR PI integrator & output (SATURATED at +-max_v_pi)
    cfg.fxp.w.str_kp  = [0, 24, 25];         % uQ-1.25: STR proportional gain Kp
    cfg.fxp.w.str_ki  = [0, 24, 31];         % uQ-7.31: STR integral gain Ki
    cfg.fxp.w.cprod   = [1, 22, 19];         % sQ2.19 : Coarse CFO lag-4 product r[n]*conj(r[n-4]) (range [-4, +4))
    cfg.fxp.w.cacc    = [1, 30, 21];         % sQ8.21 : Coarse CFO correlation accumulator (range [-256, +256))
    cfg.fxp.w.cx      = [1, 32, 22];         % sQ9.22 : CORDIC vectoring X, Y registers (range [-512, +512))
    cfg.fxp.w.cz      = [1, 28, 26];         % sQ1.26 : CORDIC angle Z accumulator in turns (range [-2, +2))
    cfg.fxp.w.cfo     = [1, 24, 24];         % sQ-1.24: Coarse CFO output word in turns/symbol (range [-0.5, +0.5))
    cfg.fxp.w.lut     = [0, 16, 16];         % uQ0.16 : Quarter-wave sine LUT entry
    cfg.fxp.w.phase   = [0, 32, 32];         % uQ0.32 : 32-bit NCO phase accumulator in turns (wraps mod 1.0) [R.120]
    cfg.fxp.w.freq_w  = [1, 32, 32];         % sQ-1.32: 32-bit signed NCO frequency word in turns/symbol
    cfg.fxp.w.rot_out = [1, 16, 14];         % sQ1.14 : Derotator & Wrapper output symbol (range [-2, +2), zero clip) [R.105]
    cfg.fxp.w.cos_a   = [1, 16, 14];         % sQ1.14 : Costas slicer decision levels (+-d, +-3d) and 2d threshold
    cfg.fxp.w.cos_e   = [1, 22, 19];         % sQ2.19 : Costas phase detector error (range [-4, +4))
    cfg.fxp.w.cos_pi  = [1, 27, 28];         % sQ-2.28: Costas PI integrator & output (SATURATED at +-max_v_pi)
    cfg.fxp.w.cos_kp  = [0, 24, 22];         % uQ2.22 : Costas proportional gain Kp
    cfg.fxp.w.cos_ki  = [0, 24, 29];         % uQ-5.29: Costas integral gain Ki
    cfg.fxp.w.sgn_cnt = [1,  5,  0];         % sQ4.0  : 5-bit signed saturating quadrant counters (-16..+15)
    cfg.fxp.w.cnt     = [0, 16,  0];         % uQ16.0 : 16-bit symbol counter
    cfg.fxp.w.lock_m  = [1, 23, 18];         % sQ4.18 : Lock detector EMA register (range [-16, +16))
    cfg.fxp.w.lock_b  = [0,  8,  0];         % uQ8.0  : Lock detector leaky bucket counter
end
