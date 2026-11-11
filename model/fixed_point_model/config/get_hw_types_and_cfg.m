function T = get_hw_types_and_cfg(cfg)
    % GET_HW_TYPES_AND_CFG  Single source of truth for all Fixed-Point Designer types,
    % fimath rules, hardware constants, LUT tables, and register latencies.
    % Built directly from the master cfg struct (get_default_config) so floating-point
    % and fixed-point models never diverge.

    if nargin < 1 || isempty(cfg)
        cfg = get_default_config();
    end

    % Determine whether to use Fixed-Point Designer (fi) or double-precision override
    has_fxp = (exist('fi', 'file') == 2) || (exist('fi', 'builtin') == 5);
    use_d   = ~strcmpi(cfg.exec_mode, 'fixed_cycle') || ~has_fxp;
    if strcmpi(cfg.exec_mode, 'fixed_cycle') && ~has_fxp
        warning('hw:nofi', 'Fixed-Point Designer not detected; falling back to float_cycle mode.');
    end

    T.use_double = use_d;
    T.cfg        = cfg;
    T.sps        = cfg.sps;
    T.in_scale   = 1.0;
    if isfield(cfg, 'wrapper_shift_en') && cfg.wrapper_shift_en
        if isfield(cfg, 'in_scale') && ~isempty(cfg.in_scale)
            T.in_scale = cfg.in_scale;
        else
            T.in_scale = 0.5;
        end
    end
    g = T.in_scale;

    % Sync mu bit-width from cfg.str.mu_bits
    w_map = cfg.fxp.w;
    if cfg.str.mu_bits > 0
        w_map.mu = [0, cfg.str.mu_bits, cfg.str.mu_bits];
    else
        w_map.mu = [0, 16, 16];
    end

    % Build numerictype and fimath tables
    nt = struct();
    fm = struct();
    if ~use_d
        rm_def = cfg.fxp.round_default;
        mk = @(rm, ov) fimath('RoundingMethod', rm, 'OverflowAction', ov, ...
                              'ProductMode', 'FullPrecision', 'SumMode', 'FullPrecision');
        fm.sat    = mk(rm_def, 'Saturate');
        fm.wrap   = mk(rm_def, 'Wrap');
        fm.sat_n  = mk('Nearest', 'Saturate');
        fm.wrap_n = mk('Nearest', 'Wrap');

        fnames = fieldnames(w_map);
        for i = 1:numel(fnames)
            spec = w_map.(fnames{i});
            nt.(fnames{i}) = numerictype(spec(1), spec(2), spec(3));
        end
    end
    T.nt  = nt;
    T.fm  = fm;
    T.w   = w_map;

    % Core type-safe helper handles (used across all step_* RTL modules)
    T.fi    = @(v, n, o) hw_make_fi(use_d, nt, fm, v, n, o);
    T.rd    = @(x) hw_rd(use_d, x);
    T.const = @(v, n) hw_const(use_d, nt, fm, v, n);
    T.wrapf = @(x) hw_wrapf(use_d, x);
    T.raw32 = @(x) hw_raw32(use_d, x);

    % Hardware pipeline latencies (clock cycles)
    T.lat.str      = max(round(cfg.fxp.lat.str), 1);
    T.lat.coarse   = max(round(cfg.fxp.lat.coarse), 1);
    T.lat.derot    = max(round(cfg.fxp.lat.derot), 1);
    T.lat.costas   = max(round(cfg.fxp.lat.costas), 1);
    T.lat.wrap_out = max(round(cfg.fxp.lat.wrap_out), 1);
    T.lat.top_total = T.lat.str + T.lat.derot + T.lat.wrap_out;

    % Constellation parameters (scaled by g = T.in_scale)
    c_qpsk = get_constellation_map(0, cfg.norm_mode);
    c_16   = get_constellation_map(1, cfg.norm_mode);
    d_q    = c_qpsk.d;
    d_16   = c_16.d;
    Es_q   = c_qpsk.avg_power;
    Es_16  = c_16.avg_power;

    % STR configuration & constants
    if strcmpi(cfg.norm_mode, 'rms')
        K_pre_ref  = 6.4772;
        K_qpsk_ref = 1.0771;
        K_16_ref   = 1.1093;
    else
        K_pre_ref  = 12.9543;
        K_qpsk_ref = 2.1541;
        K_16_ref   = 1.2326;
    end
    scale_sq = g^2;
    K_pre_sc = K_pre_ref * scale_sq;
    if cfg.mod_type == 0
        K_nom_sc = K_qpsk_ref * scale_sq;
    else
        K_nom_sc = K_16_ref   * scale_sq;
    end

    [kp_s, ki_s] = decode_gain_ports(0, cfg.str.Bn_Ts, cfg.str.zeta, K_nom_sc, cfg.str.K_nco, 0, false);
    T.str.kp       = T.const(kp_s, 'str_kp');
    T.str.ki       = T.const(ki_s, 'str_ki');
    T.str.max_v_pi = T.const(cfg.str.max_v_pi, 'str_pi');
    T.str.interp_cubic = strcmpi(cfg.str.interp_type, 'cubic');
    T.str.mu_exact     = strcmpi(cfg.str.mu_mode, 'exact');
    T.str.open_loop    = isfield(cfg.str, 'open_loop') && cfg.str.open_loop;

    % STR lock detector parameters (scaled into datapath TED units by K_pre_sc)
    T.str.lock.ema_shift = cfg.lock.ema_shift;
    T.str.lock.thr_enter = T.const(cfg.lock.str_thr_enter * K_pre_sc, 'lock_m');
    T.str.lock.thr_exit  = T.const(cfg.lock.str_thr_exit  * K_pre_sc, 'lock_m');
    T.str.lock.m0        = cfg.lock.str_m0 * K_pre_sc;
    T.str.lock.confirm   = cfg.lock.str_confirm_cnt;
    T.str.K_pre_sc       = K_pre_sc;

    % Modulo-1 and Farrow constants
    T.c.q25  = T.const(0.25, 'M');
    T.c.q75  = T.const(0.75, 'M');
    T.c.k16  = T.const(1/6,  'fk');
    T.c.k13  = T.const(1/3,  'fk');
    if use_d
        T.c.half = 0.5;
        T.c.k4   = 4.0;
        T.c.k16m = 16.0;
    else
        T.c.half = removefimath(fi(0.5, 0, 1, 1));
        T.c.k4   = removefimath(fi(4,   1, 4, 0));
        T.c.k16m = removefimath(fi(16,  1, 6, 0));
    end

    % Coarse CFO configuration & CORDIC atan table (in turns)
    T.coarse.win_len     = cfg.coarse.win_len;
    T.coarse.lag         = 4;
    T.coarse.lag_shift   = 2;
    T.coarse.cordic_iter = cfg.coarse.cordic_iter;
    T.coarse.angle_mode  = cfg.coarse.angle_mode;
    T.coarse.atan        = T.const(atan(2.^-(0:cfg.coarse.cordic_iter-1)) / (2*pi), 'cz');

    % Derotator Quarter-Wave Sine LUT (derotator.md)
    A_b     = cfg.costas.lut_addr_bits;
    Nq      = 2^A_b;
    sin_tab = sin(((0:Nq-1) + 0.5) * (pi/2) / Nq);
    lut_max = 1 - 2^(-w_map.lut(3));
    T.derot.addr_bits = A_b;
    T.derot.Nq        = Nq;
    T.derot.lut       = T.const(min(sin_tab, lut_max), 'lut');
    T.derot.mode      = cfg.costas.derot_mode;

    % Costas Loop Gains (Delay-compensated for true closed-loop symbol delay)
    loop_cycles = T.lat.derot + T.lat.costas + 1;
    if isfield(cfg.costas, 'pipe_delay') && ~isempty(cfg.costas.pipe_delay)
        pd_c = max(round(cfg.costas.pipe_delay), round(loop_cycles / cfg.sps));
    else
        pd_c = round(loop_cycles / cfg.sps);
    end
    comp_d = isfield(cfg.costas, 'compensate_delay') && cfg.costas.compensate_delay;
    K_nco  = 2 * pi;

    Es_rows = [Es_q, Es_16];
    for r = 1:2
        [ckp(r), cki(r)] = decode_gain_ports(0, cfg.costas.Bn_Ts, cfg.costas.zeta, ...
            cfg.costas.Kp_ted * Es_rows(r) * scale_sq, K_nco, pd_c, comp_d); %#ok<AGROW>
    end
    T.costas.kp = {T.const(ckp(1), 'cos_kp'), T.const(ckp(2), 'cos_kp')};
    T.costas.ki = {T.const(cki(1), 'cos_ki'), T.const(cki(2), 'cos_ki')};
    T.costas.max_v_pi = T.const(cfg.costas.max_v_pi, 'cos_pi');

    % Slicer levels and thresholds in scaled datapath units
    T.costas.lvl_q   = T.const(g * d_q,      'cos_a');
    T.costas.lvl_16a = T.const(g * d_16,     'cos_a');
    T.costas.lvl_16b = T.const(g * 3 * d_16, 'cos_a');
    T.costas.thr_16  = T.const(g * 2 * d_16, 'cos_a');
    T.costas.Es_sc   = Es_rows * scale_sq;

    % Costas Internal & Public Lock Detector Thresholds (scaled by Es_rows * g^2)
    for r = 1:2
        ksc = Es_rows(r) * scale_sq;
        T.costas.lock_int(r).ema_shift = cfg.lock.ema_shift;
        T.costas.lock_int(r).thr_enter = T.const(cfg.lock.costas_thr_enter * ksc, 'lock_m');
        T.costas.lock_int(r).thr_exit  = T.const(cfg.lock.costas_thr_exit  * ksc, 'lock_m');
        T.costas.lock_int(r).m0        = cfg.lock.costas_m0 * ksc;
        T.costas.lock_int(r).confirm   = cfg.lock.costas_confirm_cnt;

        T.costas.lock_pub(r).ema_shift = cfg.lock.ema_shift;
        T.costas.lock_pub(r).thr_enter = T.const(cfg.lock.costas_thr_enter * ksc, 'lock_m');
        T.costas.lock_pub(r).thr_exit  = T.const(cfg.lock.costas_thr_exit  * ksc, 'lock_m');
        T.costas.lock_pub(r).m0        = cfg.lock.costas_m0 * ksc;
        T.costas.lock_pub(r).confirm   = cfg.lock.costas_confirm_cnt;
    end
    T.costas.cnt_full_pos =  15;
    T.costas.cnt_full_neg = -16;
    T.costas.quad_enable  = ~isfield(cfg, 'quad') || ~isfield(cfg.quad, 'enable') || cfg.quad.enable;

    % Burst / Wrapper FSM Schedule
    T.burst.N_A = cfg.preamble.N_A;
    T.burst.N_B = cfg.preamble.N_B;
    T.burst.N_C = cfg.preamble.N_C;
    T.burst.N_pre = cfg.N_preamble;
    T.burst.fixed_start_sym = cfg.coarse.fixed_start_sym;
    T.burst.max_acq = max(T.burst.N_A + T.burst.N_B - cfg.coarse.win_len - 4, 20);
    T.wrap.pe_delay = T.lat.derot;

    % Hardware Port State Encodings
    T.enc.mode.HOLD = 0; T.enc.mode.ACQ = 1; T.enc.mode.TRACK = 2;
    T.enc.fsm.WAIT_BURST = 0; T.enc.fsm.ACQUIRE = 1; T.enc.fsm.COARSE_EST = 2;
    T.enc.fsm.LOAD = 3; T.enc.fsm.COSTAS_ACQ = 4; T.enc.fsm.TRACK = 5;
    T.enc.fsm_names = ["WAIT_BURST", "ACQUIRE", "COARSE_EST", "LOAD", "COSTAS_ACQ", "TRACK"];
    T.enc.mod.QPSK = 0; T.enc.mod.QAM16 = 1;
end

function y = hw_make_fi(use_d, nt, fm, v, n, o)
    if use_d
        y = double(v);
    else
        y = fi(v, nt.(n), fm.(o));
    end
end

function y = hw_rd(use_d, x)
    if use_d || ~isfi(x)
        y = double(x);
    else
        y = removefimath(x);
    end
end

function c = hw_const(use_d, nt, fm, v, n)
    if use_d
        c = double(v);
        return;
    end
    c = removefimath(fi(v, nt.(n), fm.sat_n));
end

function y = hw_wrapf(use_d, x)
    if use_d
        y = mod(double(x), 1.0);
    else
        y = x;
    end
end

function r = hw_raw32(use_d, x)
    if use_d
        turns = double(x) - floor(double(x));
        r = uint32(mod(floor(turns * 4294967296.0), 4294967296.0));
    else
        r = uint32(storedInteger(x));
    end
end
