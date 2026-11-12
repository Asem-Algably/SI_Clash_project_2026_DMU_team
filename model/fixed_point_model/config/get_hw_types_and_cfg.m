function T = get_hw_types_and_cfg(cfg)
    % GET_HW_TYPES_AND_CFG  Single source of truth for all Fixed-Point Designer types,
    % fimath rules, hardware constants, LUT tables, and register latencies.
    %
    % Hardware Datapath Architecture:
    %   - Sized with MSB guard bits so datapath registers operate in pure 2's-complement
    %     wrapping ('wrap') mode without arithmetic overflow.
    %   - Saturation ('sat') logic is restricted strictly to the STR and Costas PI loop filters.
    %   - Parabolic Farrow interpolator is used exclusively (cubic paths eliminated).
    %
    % Inputs:
    %   cfg - Master configuration struct from get_default_config()
    %
    % Outputs:
    %   T   - Complete hardware definitions struct with types (nt), fimath (fm),
    %         pipeline latencies (lat), loop filter constants, and LUT tables.

    T.cfg      = cfg;
    T.sps      = cfg.sps;
    T.in_scale = cfg.in_scale;
    g          = T.in_scale;

    % Build numerictype and fimath tables
    w_map  = cfg.fxp.w;
    rm_def = cfg.fxp.round_default;
    mk     = @(rm, ov) fimath('RoundingMethod', rm, 'OverflowAction', ov, ...
                              'ProductMode', 'FullPrecision', 'SumMode', 'FullPrecision');
    fm.wrap   = mk(rm_def,    'Wrap');
    fm.wrap_n = mk('Nearest', 'Wrap');
    fm.sat    = mk(rm_def,    'Saturate');
    fm.sat_n  = mk('Nearest', 'Saturate');

    nt = struct();
    fnames = fieldnames(w_map);
    for i = 1:numel(fnames)
        spec = w_map.(fnames{i});
        nt.(fnames{i}) = numerictype(spec(1), spec(2), spec(3));
    end
    T.nt = nt;
    T.fm = fm;
    T.w  = w_map;

    % Core type-safe Fixed-Point helper handles (default overflow mode is 'wrap')
    T.fi    = @(v, n, varargin) hw_make_fi(nt, fm, v, n, varargin{:});
    T.rd    = @(x) removefimath(x);
    T.const = @(v, n) removefimath(fi(v, nt.(n), fm.sat_n));
    T.raw32 = @(x) uint32(storedInteger(x));

    % Hardware pipeline latencies (clock cycles)
    T.lat.str       = max(round(cfg.fxp.lat.str), 1);
    T.lat.coarse    = max(round(cfg.fxp.lat.coarse), 1);
    T.lat.derot     = max(round(cfg.fxp.lat.derot), 1);
    T.lat.costas    = max(round(cfg.fxp.lat.costas), 1);
    T.lat.wrap_out  = max(round(cfg.fxp.lat.wrap_out), 1);
    T.lat.top_total = T.lat.str + T.lat.derot + T.lat.wrap_out;

    % Constellation parameters (scaled by g = T.in_scale = 0.5)
    c_qpsk = get_constellation_map(0, cfg.norm_mode);
    c_16   = get_constellation_map(1, cfg.norm_mode);
    d_q    = c_qpsk.d;
    d_16   = c_16.d;
    Es_q   = c_qpsk.avg_power;
    Es_16  = c_16.avg_power;

    % STR configuration & constants (scaled by g^2 = 0.25)
    K_pre_ref  = 12.9543;
    K_qpsk_ref = 2.1541;
    K_16_ref   = 1.2326;
    scale_sq   = g^2;
    K_pre_sc   = K_pre_ref * scale_sq;
    if cfg.mod_type == 0
        K_nom_sc = K_qpsk_ref * scale_sq;
    else
        K_nom_sc = K_16_ref   * scale_sq;
    end

    [kp_s, ki_s] = compute_loop_gains(cfg.str.Bn_Ts, cfg.str.zeta, K_nom_sc, cfg.str.K_nco, 0, false);
    T.str.kp           = T.const(kp_s, 'str_kp');
    T.str.ki           = T.const(ki_s, 'str_ki');
    T.str.max_v_pi     = T.const(cfg.str.max_v_pi, 'str_pi');
    T.str.open_loop    = isfield(cfg.str, 'open_loop') && cfg.str.open_loop;

    % STR lock detector parameters (scaled into datapath TED units by K_pre_sc)
    T.str.lock.ema_shift = cfg.lock.ema_shift;
    T.str.lock.thr_enter = T.const(cfg.lock.str_thr_enter * K_pre_sc, 'lock_m');
    T.str.lock.thr_exit  = T.const(cfg.lock.str_thr_exit  * K_pre_sc, 'lock_m');
    T.str.lock.m0        = cfg.lock.str_m0 * K_pre_sc;
    T.str.lock.confirm   = cfg.lock.str_confirm_cnt;
    T.str.K_pre_sc       = K_pre_sc;

    % Modulo-1 and Farrow shift constants
    T.c.q25  = T.const(0.25, 'M');
    T.c.q75  = T.const(0.75, 'M');
    T.c.half = removefimath(fi(0.5, 0, 1, 1));
    T.c.k4   = removefimath(fi(4,   1, 4, 0));
    T.c.k16m = removefimath(fi(16,  1, 6, 0));

    % Coarse CFO configuration & CORDIC atan table (in turns)
    T.coarse.win_len     = cfg.coarse.win_len;
    T.coarse.lag         = 4;
    T.coarse.lag_shift   = 2;
    T.coarse.cordic_iter = cfg.coarse.cordic_iter;
    T.coarse.atan        = T.const(atan(2.^-(0:cfg.coarse.cordic_iter-1)) / (2*pi), 'cz');

    % Derotator Quarter-Wave Sine LUT
    A_b     = cfg.costas.lut_addr_bits;
    Nq      = 2^A_b;
    sin_tab = sin(((0:Nq-1) + 0.5) * (pi/2) / Nq);
    lut_max = 1 - 2^(-w_map.lut(3));
    T.derot.addr_bits = A_b;
    T.derot.Nq        = Nq;
    T.derot.lut       = T.const(min(sin_tab, lut_max), 'lut');

    % Costas Loop Gains (Single fixed gain per modulation, delay-compensated)
    loop_cycles = T.lat.derot + T.lat.costas + 1;
    pd_c        = max(round(cfg.costas.pipe_delay), round(loop_cycles / cfg.sps));
    comp_d      = isfield(cfg.costas, 'compensate_delay') && cfg.costas.compensate_delay;
    K_nco       = 2 * pi;

    Es_rows = [Es_q, Es_16];
    for r = 1:2
        [ckp(r), cki(r)] = compute_loop_gains(cfg.costas.Bn_Ts, cfg.costas.zeta, ...
            cfg.costas.Kp_ted * Es_rows(r) * scale_sq, K_nco, pd_c, comp_d); %#ok<AGROW>
    end
    T.costas.kp = {T.const(ckp(1), 'cos_kp'), T.const(ckp(2), 'cos_kp')};
    T.costas.ki = {T.const(cki(1), 'cos_ki'), T.const(cki(2), 'cos_ki')};
    T.costas.max_v_pi = T.const(cfg.costas.max_v_pi, 'cos_pi');

    % Slicer levels and thresholds in /2 scaled datapath units (QPSK: +-0.5; 16-QAM: +-1/6, +-0.5, thr=1/3)
    T.costas.lvl_q   = T.const(g * d_q,      'cos_a');
    T.costas.lvl_16a = T.const(g * d_16,     'cos_a');
    T.costas.lvl_16b = T.const(g * 3 * d_16, 'cos_a');
    T.costas.thr_16  = T.const(g * 2 * d_16, 'cos_a');
    T.costas.Es_sc   = Es_rows * scale_sq;

    % Costas Internal & Public Lock Detector Thresholds
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

function y = hw_make_fi(nt, fm, v, n, varargin)
    ov = 'wrap';
    if numel(varargin) >= 1
        ov = varargin{1};
    end
    y = fi(v, nt.(n), fm.(ov));
end
