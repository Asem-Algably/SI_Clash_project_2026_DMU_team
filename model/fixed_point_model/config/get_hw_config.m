function cfg = get_hw_config()
    % GET_HW_CONFIG  Unified Master Hardware Configuration for Fixed-Point Synchronizer.
    %
    % Consolidates all system parameters, bus widths, fixed-point types,
    % loop filter gains, quarter-wave sine LUT, and FSM encodings into a single file.

    % =====================================================================
    % 1. TOP-LEVEL SYSTEM & CHANNEL PARAMETERS
    % =====================================================================
    cfg.F_clk            = 125e6;            % System clock: 125 MHz [R.101]
    cfg.sps              = 4;                % Samples per symbol: Ns = 4 [R.102]
    cfg.R_sym            = cfg.F_clk / cfg.sps; % Symbol rate: 31.25 MSps [R.103]
    cfg.mod_type         = 1;                % Default payload: 0 = QPSK, 1 = 16-QAM [R.107]
    cfg.rrc_alpha        = 0.35;             % RRC roll-off factor [CP6]
    cfg.rrc_span         = 10;               % Filter span in symbols
    cfg.N_payload        = 1200;             % Payload symbols (>= 1000 for CP6)
    cfg.seed             = 42;               % RNG seed for reproducibility
    cfg.in_scale         = 0.5;              % Front-end ADC /2 scaling (maps [-2, +2) into [-1, +1) Q1.11)

    % Channel impairment defaults
    cfg.snr_dB           = 18.0;             % Nominal SNR (dB)
    cfg.snr_def          = 'sample';         % 'sample' or 'esn0'
    cfg.tau_offset       = 0.35;             % Fractional timing delay [0, 1) Ts [CP2]
    cfg.cfo_norm         = 0.065;            % Normalized carrier frequency offset (turns/symbol) [R.113]
    cfg.phase_offset     = 115 * (pi / 180); % Initial carrier phase offset (rad)

    % =====================================================================
    % 2. PREAMBLE SPECIFICATION (190 SYMBOLS TOTAL)
    % =====================================================================
    % Phase A1 (STR Acquire) : 70 symbols, alternating diagonal Q4/Q2
    % Phase A2 (Coarse CFO)  : 40 symbols, alternating diagonal Q4/Q2 (WinLen = 32, Lag = 4)
    % Phase B  (Costas Pull) : 30 symbols, alternating diagonal Q4/Q2
    % Phase C  (Quadrant Res): 50 symbols, repeated sequence [Q1, Q2, Q1, Q4]
    cfg.preamble.N_A     = 70;
    cfg.preamble.N_cfo   = 40;
    cfg.preamble.N_B     = 30;
    cfg.preamble.N_C     = 50;
    cfg.N_preamble       = cfg.preamble.N_A + cfg.preamble.N_cfo + cfg.preamble.N_B + cfg.preamble.N_C; % 190

    % =====================================================================
    % 3. HARDWARE SUBMODULE PIPELINE LATENCIES (CLOCK CYCLES)
    % =====================================================================
    cfg.lat.farrow       = 4;                % Parabolic Farrow Horner MAC pipeline depth
    cfg.lat.ted          = 1;                % Gardner TED registered multiplier/adder
    cfg.lat.str_pi       = 1;                % STR PI filter registered accumulator
    cfg.lat.str          = cfg.lat.farrow;   % STR module strobe alignment latency
    cfg.lat.coarse       = 16;               % 16-stage vectoring CORDIC IP latency
    cfg.lat.derot        = 2;                % 1 LUT read cycle + 1 complex multiplier cycle
    cfg.lat.costas       = 1;                % Costas PI filter registered accumulator
    cfg.lat.wrap_out     = 1;                % Top wrapper output register stage
    cfg.lat.top_total    = cfg.lat.str + cfg.lat.derot + cfg.lat.wrap_out;

    % =====================================================================
    % 4. HARDWARE BUS WIDTHS [Signed, WordLength, FractionLength]
    % =====================================================================
    cfg.w.in             = [1, 12, 11];      % sQ0.11 : ADC input port in [-1, 1 - 2^-11] [R.104]
    cfg.w.fv             = [1, 16, 12];      % sQ3.12 : Farrow v1, v2 polynomial coeffs
    cfg.w.fh             = [1, 17, 13];      % sQ3.13 : Farrow Horner MAC intermediate stage
    cfg.w.str_sym        = [1, 16, 14];      % sQ1.14 : STR interpolated symbol output
    cfg.w.M              = [0, 24, 24];      % uQ0.24 : Modulo-1 counter M and step W (wraps mod 1.0)
    cfg.w.M_s            = [1, 25, 24];      % sQ0.24 : Signed 25-bit Modulo-1 difference wire
    cfg.w.eta            = [1, 19, 18];      % sQ0.18 : Signed distance above strobe boundary
    cfg.w.pi_mu          = [1, 18, 17];      % sQ0.17 : PI filter output feeding linear mu multiplier
    cfg.w.mu             = [1, 12, 10];      % sQ1.10 : Fractional interval mu (10 frac bits [R.110])
    cfg.w.ted_d          = [1, 17, 14];      % sQ2.14 : Gardner TED difference (cur - prev)
    cfg.w.ted_e          = [1, 25, 21];      % sQ3.21 : Gardner TED error output
    cfg.w.str_pi         = [1, 26, 28];      % sQ-3.28: STR PI integrator & output (SATURATING)
    cfg.w.str_kp         = [0, 24, 25];      % uQ-1.25: STR proportional gain Kp
    cfg.w.str_ki         = [0, 24, 31];      % uQ-7.31: STR integral gain Ki
    cfg.w.cprod          = [1, 22, 19];      % sQ2.19 : Coarse CFO lag-4 product r[n]*conj(r[n-4])
    cfg.w.cacc           = [1, 30, 21];      % sQ8.21 : Coarse CFO correlation accumulator
    cfg.w.cx             = [1, 32, 22];      % sQ9.22 : CORDIC vectoring X, Y registers
    cfg.w.cz             = [1, 28, 26];      % sQ1.26 : CORDIC angle Z accumulator in turns
    cfg.w.cfo            = [1, 24, 24];      % sQ-1.24: Coarse CFO output word in turns/symbol
    cfg.w.lut            = [0, 16, 16];      % uQ0.16 : Quarter-wave sine LUT entry
    cfg.w.phase          = [0, 32, 32];      % uQ0.32 : 32-bit NCO phase accumulator in turns [R.120]
    cfg.w.freq_w         = [1, 32, 32];      % sQ-1.32: 32-bit signed NCO frequency word in turns/symbol
    cfg.w.rot_out        = [1, 16, 14];      % sQ1.14 : Derotator output symbol [R.105]
    cfg.w.cos_a          = [1, 16, 14];      % sQ1.14 : Costas slicer decision levels (+-d, +-3d)
    cfg.w.cos_e          = [1, 22, 19];      % sQ2.19 : Costas phase detector error
    cfg.w.cos_pi         = [1, 27, 28];      % sQ-2.28: Costas PI integrator & output (SATURATING)
    cfg.w.cos_kp         = [0, 24, 22];      % uQ2.22 : Costas proportional gain Kp
    cfg.w.cos_ki         = [0, 24, 29];      % uQ-5.29: Costas integral gain Ki
    cfg.w.sgn_cnt        = [1,  5,  0];      % sQ4.0  : 5-bit signed saturating quadrant counters (-16..+15)
    cfg.w.cnt            = [0, 16,  0];      % uQ16.0 : 16-bit symbol counter
    cfg.w.lock_m         = [1, 23, 18];      % sQ4.18 : Lock detector EMA register
    cfg.w.lock_b         = [0,  8,  0];      % uQ8.0  : Lock detector leaky bucket counter

    % =====================================================================
    % 5. NUMERICTYPES, FIMATHS & TYPE CONSTRUCTORS
    % =====================================================================
    fn = fieldnames(cfg.w);
    for k = 1:numel(fn)
        spec = cfg.w.(fn{k});
        cfg.nt.(fn{k}) = numerictype(spec(1), spec(2), spec(3));
    end

    cfg.fm.wrap   = fimath('RoundingMethod', 'Floor',   'OverflowAction', 'Wrap');
    cfg.fm.wrap_n = fimath('RoundingMethod', 'Nearest', 'OverflowAction', 'Wrap');
    cfg.fm.sat    = fimath('RoundingMethod', 'Floor',   'OverflowAction', 'Saturate');
    cfg.fm.sat_n  = fimath('RoundingMethod', 'Nearest', 'OverflowAction', 'Saturate');

    cfg.fi    = @(v, n, varargin) hw_make_fi(cfg.nt, cfg.fm, v, n, varargin{:});
    cfg.rd    = @(x) removefimath(x);
    cfg.const = @(v, n) setfimath(fi(v, cfg.nt.(n)), cfg.fm.wrap);
    cfg.raw32 = @(x) uint32(storedInteger(x));

    % Hardware datapath bit-exact constants
    cfg.c.q25  = cfg.const(0.25, 'M');
    cfg.c.q75  = cfg.const(0.75, 'M');
    cfg.c.half = removefimath(fi(0.5, 0, 1, 1));
    cfg.c.k4   = removefimath(fi(4,   1, 4, 0));
    cfg.c.k16m = removefimath(fi(16,  1, 6, 0));

    % =====================================================================
    % 6. STR & COSTAS LOOP GAINS (PEAK NORMALIZATION)
    % =====================================================================
    % Peak normalization constellation powers:
    % QPSK: symbols +-1 +- 1j -> Es = 1^2 + 1^2 = 2.0
    % 16-QAM: symbols +-1/3, +-1 -> Es = (1 + 1/9 + 1/9 + 1)/2 = 10/9 = 1.1111
    Es_q       = 2.0;
    Es_16      = 10.0 / 9.0;
    g          = cfg.in_scale;
    scale_sq   = g * g; % 0.25
    K_pre_ref  = 12.9543;
    K_qpsk_ref = 2.1541;
    K_16_ref   = 1.2326;
    K_pre_sc   = K_pre_ref * scale_sq;
    if cfg.mod_type == 0
        K_nom_sc = K_qpsk_ref * scale_sq;
    else
        K_nom_sc = K_16_ref   * scale_sq;
    end

    % STR Loop Filter Gains (Kp, Ki)
    cfg.str.zeta     = 0.707;
    cfg.str.Bn_Ts    = 0.010;
    cfg.str.K_nco    = 4.0;
    cfg.str.W_nom    = 1.0 / cfg.sps; % 0.25
    cfg.str.max_v_pi = 0.035;
    [skp, ski]       = calc_loop_gains(cfg.str.Bn_Ts, cfg.str.zeta, K_nom_sc, cfg.str.K_nco, 0, false);
    cfg.str.kp       = cfg.const(skp, 'str_kp');
    cfg.str.ki       = cfg.const(ski, 'str_ki');
    cfg.str.max_pi   = cfg.const(cfg.str.max_v_pi, 'str_pi');

    % Costas Loop Filter Gains (Delay-Compensated for QPSK row 1 and 16-QAM row 2)
    cfg.costas.zeta       = 0.707;
    cfg.costas.Bn_Ts      = 0.025;
    cfg.costas.max_v_pi   = 0.12;
    loop_delay_syms       = max(round((cfg.lat.derot + cfg.lat.costas + 1) / cfg.sps), 1);
    Es_rows               = [Es_q, Es_16];
    for r = 1:2
        [ckp, cki] = calc_loop_gains(cfg.costas.Bn_Ts, cfg.costas.zeta, ...
            Es_rows(r) * scale_sq, 2 * pi, loop_delay_syms, true);
        cfg.costas.kp{r} = cfg.const(ckp, 'cos_kp');
        cfg.costas.ki{r} = cfg.const(cki, 'cos_ki');
    end
    cfg.costas.max_pi = cfg.const(cfg.costas.max_v_pi, 'cos_pi');

    % =====================================================================
    % 7. SLICER LEVELS & THRESHOLDS (IN /2 SCALED DOMAIN)
    % =====================================================================
    cfg.costas.lvl_q   = cfg.const(g * 1.0,           'cos_a'); % QPSK: +-0.5
    cfg.costas.lvl_16a = cfg.const(g * (1.0 / 3.0),   'cos_a'); % 16-QAM inner: +-1/6
    cfg.costas.lvl_16b = cfg.const(g * 1.0,           'cos_a'); % 16-QAM outer: +-0.5
    cfg.costas.thr_16  = cfg.const(g * (2.0 / 3.0),   'cos_a'); % 16-QAM threshold: 1/3

    % =====================================================================
    % 8. QUARTER-WAVE SINE LUT (4096 ENTRIES, 12-BIT ADDRESS, uQ0.16)
    % =====================================================================
    cfg.derot.addr_bits = 12;
    cfg.derot.Nq        = 2^cfg.derot.addr_bits; % 4096
    a_idx               = (0 : cfg.derot.Nq - 1).';
    sin_mid             = sin((a_idx + 0.5) * (pi / 2) / cfg.derot.Nq);
    lut_raw             = round(sin_mid * (2^16 - 1)) / (2^16);
    cfg.derot.lut       = cfg.const(lut_raw, 'lut');

    % =====================================================================
    % 9. LOCK DETECTORS & SIGN COUNTERS
    % =====================================================================
    cfg.lock.ema_shift          = 4;
    cfg.lock.str_confirm        = 20;
    cfg.lock.str_thr_enter      = cfg.const(0.060 * K_pre_sc, 'lock_m');
    cfg.lock.str_thr_exit       = cfg.const(0.150 * K_pre_sc, 'lock_m');
    cfg.lock.str_m0             = 0.300 * K_pre_sc;

    for r = 1:2
        ksc = Es_rows(r) * scale_sq;
        cfg.costas.lock_int(r).ema_shift = cfg.lock.ema_shift;
        cfg.costas.lock_int(r).thr_enter = cfg.const(0.200 * ksc, 'lock_m');
        cfg.costas.lock_int(r).thr_exit  = cfg.const(0.300 * ksc, 'lock_m');
        cfg.costas.lock_int(r).m0        = cfg.const(0.350 * ksc, 'lock_m');
        cfg.costas.lock_int(r).confirm   = 12;

        cfg.costas.lock_pub(r).ema_shift = cfg.lock.ema_shift;
        cfg.costas.lock_pub(r).thr_enter = cfg.const(0.200 * ksc, 'lock_m');
        cfg.costas.lock_pub(r).thr_exit  = cfg.const(0.300 * ksc, 'lock_m');
        cfg.costas.lock_pub(r).m0        = cfg.const(0.350 * ksc, 'lock_m');
        cfg.costas.lock_pub(r).confirm   = 12;
    end
    cfg.costas.cnt_full_pos =  15;
    cfg.costas.cnt_full_neg = -16;

    % =====================================================================
    % 10. FSM STATE & MODE ENCODINGS
    % =====================================================================
    cfg.enc.fsm.WAIT_BURST = 0;
    cfg.enc.fsm.ACQUIRE    = 1;
    cfg.enc.fsm.COARSE_EST = 2;
    cfg.enc.fsm.LOAD       = 3;
    cfg.enc.fsm.COSTAS_ACQ = 4;
    cfg.enc.fsm.TRACK      = 5;
    cfg.enc.fsm_names      = ["WAIT_BURST", "ACQUIRE", "COARSE_EST", "LOAD", "COSTAS_ACQ", "TRACK"];

    cfg.enc.mode.HOLD      = 0;
    cfg.enc.mode.ACQ       = 1;
    cfg.enc.mode.TRACK     = 2;

    cfg.enc.mod.QPSK       = 0;
    cfg.enc.mod.QAM16      = 1;
end

% --- Helper Functions ---
function y = hw_make_fi(nt, fm, v, n, varargin)
    ov = 'wrap';
    if nargin >= 5 && ~isempty(varargin{1})
        ov = varargin{1};
    end
    y = fi(v, nt.(n), fm.(ov));
end

function [Kp, Ki] = calc_loop_gains(Bn_Ts, zeta, K_ted, K_nco, pipe_delay, comp_delay)
    theta = Bn_Ts / (zeta + 1.0 / (4.0 * zeta));
    d     = 1.0 + 2.0 * zeta * theta + theta^2;
    Kp    = (4.0 * zeta * theta / d) / (K_ted * K_nco);
    Ki    = (4.0 * theta^2 / d) / (K_ted * K_nco);
    if comp_delay && (pipe_delay > 0)
        % Bisection delay reduction factor
        scale = max(1.0 - 0.12 * pipe_delay, 0.50);
        Kp    = Kp * scale;
        Ki    = Ki * scale;
    end
end
