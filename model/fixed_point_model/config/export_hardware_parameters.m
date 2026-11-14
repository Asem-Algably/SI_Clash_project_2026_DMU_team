function export_hardware_parameters(cfg, filename)
    % EXPORT_HARDWARE_PARAMETERS  Export hardware parameters, loop gains,
    % bit-widths, valid/flush timing, and Verilog hex literals for RTL implementation.
    %
    % Inputs:
    %   cfg      - Master hardware configuration struct from get_hw_config()
    %   filename - (Optional) Destination text file path; defaults to config/hw_parameters_exported.txt

    if nargin < 1 || isempty(cfg)
        cfg = get_hw_config();
    end

    if nargin < 2 || isempty(filename)
        filename = fullfile(fileparts(mfilename('fullpath')), 'hw_parameters_exported.txt');
    end

    fid = fopen(filename, 'w');
    if fid == -1
        error('export_hw:io', 'Could not open file %s for writing.', filename);
    end

    row_idx = min(cfg.mod_type, 1) + 1;
    if cfg.mod_type == 0
        mod_name = 'QPSK';
    else
        mod_name = '16-QAM';
    end

    fprintf(fid, '==================================================================================================================\n');
    fprintf(fid, '  SI-CLASH MASTER SYNCHRONIZER HARDWARE PARAMETERS & REGISTER EXPORT REPORT\n');
    fprintf(fid, '  Target Architecture: Pure Fixed-Point Cycle-Accurate Digital Synchronizer (RTL Reference)\n');
    fprintf(fid, '==================================================================================================================\n');
    fprintf(fid, '  System Clock (F_clk)      : %.2f MHz [R.101]\n', cfg.F_clk / 1e6);
    fprintf(fid, '  Samples Per Symbol (sps)  : %d samples/symbol [R.102]\n', cfg.sps);
    fprintf(fid, '  Symbol Rate (R_sym)       : %.2f MSps [R.103]\n', cfg.R_sym / 1e6);
    fprintf(fid, '  Default Modulation        : %s (mod_type = %d) [R.107]\n', mod_name, cfg.mod_type);
    fprintf(fid, '  Front-End Scale (/2)      : %.4f (maps [-2, +2) to [-1, 1 - 2^-11) Q1.11 at input)\n', cfg.in_scale);
    fprintf(fid, '  Preamble Schedule         : A1 (STR) = %d, A2 (CFO) = %d, B (Costas) = %d, C (Quad) = %d (Total = %d syms)\n', ...
        cfg.preamble.N_A, cfg.preamble.N_cfo, cfg.preamble.N_B, cfg.preamble.N_C, cfg.N_preamble);
    fprintf(fid, '\n');

    % ---------------------------------------------------------------------
    % SECTION 1: VALID, WATCHDOG & FLUSH CONFIGURATION
    % ---------------------------------------------------------------------
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  1. VALID SIGNAL, WATCHDOG & FLUSH TIMING SPECIFICATION\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  Hardware Valid Enable     : %d (STR clock-enabled via ce_str = s_axis_valid_i | flush_active)\n', cfg.valid.enable);
    fprintf(fid, '  Idle Watchdog Timeout     : %d consecutive invalid clocks (triggers FLUSH state)\n', cfg.valid.idle_timeout);
    fprintf(fid, '  Flush Fill Mode           : %s (samples fed to STR during FLUSH)\n', cfg.valid.flush_fill);
    fprintf(fid, '  Flush Safety Margin       : %d clock cycles\n', cfg.valid.flush_margin);
    fprintf(fid, '  Derived Flush Duration (F): %d clock cycles\n', cfg.valid.flush_clocks);
    fprintf(fid, '    Formula : F = sps (%d) + lat.str (%d) + lat.derot (%d) + lat.wrap_out (%d) + margin (%d) = %d clocks\n', ...
        cfg.sps, cfg.lat.str, cfg.lat.derot, cfg.lat.wrap_out, cfg.valid.flush_margin, cfg.valid.flush_clocks);
    fprintf(fid, '  Downstream Pipeline Action: Free-running on wall clock; soft-reset clears all modules at end of FLUSH (F clocks)\n');
    fprintf(fid, '\n');

    % ---------------------------------------------------------------------
    % SECTION 2: FIXED-POINT PI LOOP FILTER GAINS
    % ---------------------------------------------------------------------
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  2. FIXED-POINT PI LOOP FILTER GAINS (Stored Integer & Verilog Hex Literals)\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    [str_kp_int, str_kp_hex, str_kp_fmt] = format_hw_hex(cfg.str.kp, cfg.w.str_kp);
    [str_ki_int, str_ki_hex, str_ki_fmt] = format_hw_hex(cfg.str.ki, cfg.w.str_ki);
    fprintf(fid, '  STR Loop Filter (str.md | Bn_Ts = %.3f, zeta = %.3f, K_nco = 4.0):\n', cfg.str.Bn_Ts, cfg.str.zeta);
    fprintf(fid, '    STR Kp    (%s) : Real = %12.8f | Stored Int = %10d | RTL Hex = %s\n', ...
        str_kp_fmt, double(cfg.str.kp), str_kp_int, str_kp_hex);
    fprintf(fid, '    STR Ki    (%s) : Real = %12.8f | Stored Int = %10d | RTL Hex = %s\n', ...
        str_ki_fmt, double(cfg.str.ki), str_ki_int, str_ki_hex);
    fprintf(fid, '    STR Saturation Limit   : +-%.4f (anti-windup saturation)\n', double(cfg.str.max_pi));
    fprintf(fid, '\n');

    [cos_kp_int, cos_kp_hex, cos_kp_fmt] = format_hw_hex(cfg.costas.kp{row_idx}, cfg.w.cos_kp);
    [cos_ki_int, cos_ki_hex, cos_ki_fmt] = format_hw_hex(cfg.costas.ki{row_idx}, cfg.w.cos_ki);
    fprintf(fid, '  Costas Loop Filter (costas.md | %s | Bn_Ts = %.3f, zeta = %.3f, K_nco = 2*pi):\n', ...
        mod_name, cfg.costas.Bn_Ts, cfg.costas.zeta);
    fprintf(fid, '    Costas Kp (%s) : Real = %12.8f | Stored Int = %10d | RTL Hex = %s\n', ...
        cos_kp_fmt, double(cfg.costas.kp{row_idx}), cos_kp_int, cos_kp_hex);
    fprintf(fid, '    Costas Ki (%s) : Real = %12.8f | Stored Int = %10d | RTL Hex = %s\n', ...
        cos_ki_fmt, double(cfg.costas.ki{row_idx}), cos_ki_int, cos_ki_hex);
    fprintf(fid, '    Costas Saturation Limit: +-%.4f (anti-windup saturation)\n', double(cfg.costas.max_pi));
    fprintf(fid, '\n');

    % ---------------------------------------------------------------------
    % SECTION 3: LOCK DETECTOR & AMBIGUITY RESOLUTION CONSTANTS
    % ---------------------------------------------------------------------
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  3. LOCK DETECTOR & QUADRANT AMBIGUITY SPECIFICATION\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    [s_ent_int, s_ent_hex, lk_fmt] = format_hw_hex(cfg.lock.str_thr_enter, cfg.w.lock_m);
    [s_ext_int, s_ext_hex, ~]      = format_hw_hex(cfg.lock.str_thr_exit,  cfg.w.lock_m);
    fprintf(fid, '  STR Lock Detector (str.md | ema_shift = %d, confirm_cnt = %d):\n', ...
        cfg.lock.ema_shift, cfg.lock.str_confirm);
    fprintf(fid, '    str_thr_enter    (%s) : Real = %10.6f | Stored Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(cfg.lock.str_thr_enter), s_ent_int, s_ent_hex);
    fprintf(fid, '    str_thr_exit     (%s) : Real = %10.6f | Stored Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(cfg.lock.str_thr_exit),  s_ext_int, s_ext_hex);
    fprintf(fid, '\n');

    [c_ent_int, c_ent_hex, ~] = format_hw_hex(cfg.costas.lock_pub(row_idx).thr_enter, cfg.w.lock_m);
    [c_ext_int, c_ext_hex, ~] = format_hw_hex(cfg.costas.lock_pub(row_idx).thr_exit,  cfg.w.lock_m);
    fprintf(fid, '  Costas Lock Detector (costas.md | %s | ema_shift = %d, confirm_cnt = %d):\n', ...
        mod_name, cfg.costas.lock_pub(row_idx).ema_shift, cfg.costas.lock_pub(row_idx).confirm);
    fprintf(fid, '    costas_thr_enter (%s) : Real = %10.6f | Stored Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(cfg.costas.lock_pub(row_idx).thr_enter), c_ent_int, c_ent_hex);
    fprintf(fid, '    costas_thr_exit  (%s) : Real = %10.6f | Stored Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(cfg.costas.lock_pub(row_idx).thr_exit),  c_ext_int, c_ext_hex);
    fprintf(fid, '  Costas Sign Counters     : 5-bit signed saturating up/down counters in [%d, +%d]\n', ...
        cfg.costas.cnt_full_neg, cfg.costas.cnt_full_pos);
    fprintf(fid, '\n');

    % ---------------------------------------------------------------------
    % SECTION 4: LATENCIES & PIPELINE DEPTHS
    % ---------------------------------------------------------------------
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  4. HARDWARE PIPELINE LATENCIES (Clock Cycles)\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  STR Farrow Interpolator   : %2d cycles (Parabolic Horner MAC pipeline)\n', cfg.lat.farrow);
    fprintf(fid, '  Gardner TED Pipeline      : %2d cycle\n', cfg.lat.ted);
    fprintf(fid, '  STR PI Filter Register    : %2d cycle\n', cfg.lat.str_pi);
    fprintf(fid, '  Coarse CFO CORDIC IP      : %2d cycles (16 vectoring iterations)\n', cfg.lat.coarse);
    fprintf(fid, '  Derotator (LUT + Mult)    : %2d cycles (1 LUT read + 1 complex mult)\n', cfg.lat.derot);
    fprintf(fid, '  Costas PI Filter Register : %2d cycle\n', cfg.lat.costas);
    fprintf(fid, '  Top Wrapper Output Stage  : %2d cycle\n', cfg.lat.wrap_out);
    fprintf(fid, '  Steady-State Latency      : %2d cycles (lat.str + lat.derot + lat.wrap_out <= 64 [R.106])\n', cfg.lat.top_total);
    fprintf(fid, '\n');

    % ---------------------------------------------------------------------
    % SECTION 5: REGISTER BUS WIDTHS & TYPES
    % ---------------------------------------------------------------------
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  5. HARDWARE REGISTER MAP, BUS WIDTHS & FIXED-POINT FORMATS\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  %-10s | %-20s | %-10s | %s\n', 'Register', 'Type Spec [S, WL, FL]', 'Format', 'RTL Hardware Function');
    fprintf(fid, '  -----------+----------------------+------------+--------------------------------------------------------\n');

    desc_map = get_register_descriptions();
    fn = fieldnames(cfg.w);
    for k = 1:numel(fn)
        bname = fn{k};
        spec  = cfg.w.(bname);
        if spec(1) == 1
            sgn_s = 'Signed  ';
            int_b = spec(2) - 1 - spec(3);
            q_str = sprintf('sQ%d.%d', int_b, spec(3));
        else
            sgn_s = 'Unsigned';
            int_b = spec(2) - spec(3);
            q_str = sprintf('uQ%d.%d', int_b, spec(3));
        end
        if isfield(desc_map, bname)
            d_str = desc_map.(bname);
        else
            d_str = 'Datapath register';
        end
        fprintf(fid, '  %-10s | [%s, WL=%2d, FL=%2d] | %-10s | %s\n', ...
            bname, sgn_s, spec(2), spec(3), q_str, d_str);
    end
    fprintf(fid, '==================================================================================================================\n');
    fclose(fid);

    fprintf('[EXPORT] Master hardware parameters exported to: %s\n', filename);
end

% --- Helper Functions ---
function [stored_int, rtl_hex, fmt_str] = format_hw_hex(val, spec)
    sgn   = spec(1);
    wl    = spec(2);
    fl    = spec(3);
    int_b = wl - sgn - fl;
    if sgn == 1
        fmt_str = sprintf('sQ%d.%d, %2d-bit', int_b, fl, wl);
    else
        fmt_str = sprintf('uQ%d.%d, %2d-bit', int_b, fl, wl);
    end

    if isfi(val)
        stored_int = double(storedInteger(val));
        hex_raw    = upper(hex(val));
    else
        stored_int = round(double(val) * (2^fl));
        if stored_int < 0
            stored_int_u = stored_int + 2^wl;
        else
            stored_int_u = stored_int;
        end
        n_nibbles = ceil(wl / 4);
        hex_raw   = dec2hex(stored_int_u, n_nibbles);
    end
    rtl_hex = sprintf('%d''h%s', wl, hex_raw);
end

function d = get_register_descriptions()
    d.in      = '[ADC In]         Input I/Q sample (in_sample_i/q) after /2 scale, in [-1, 1 - 2^-11]';
    d.fv      = '[STR Farrow]     Parabolic Farrow polynomial coeffs v1, v2';
    d.fh      = '[STR Farrow]     Parabolic Farrow Horner MAC intermediate stage';
    d.str_sym = '[STR Sym Out]    Interpolated I/Q symbol (m_axis_i/q_sym_o)';
    d.M       = '[STR Controller] Modulo-1 phase counter M and step register W';
    d.M_s     = '[STR Controller] Signed 25-bit Modulo-1 difference wire';
    d.eta     = '[STR Controller] Distance above strobe boundary (M - 0.25 / M - 0.75)';
    d.pi_mu   = '[STR Controller] Loop filter output feeding linear mu multiplier';
    d.mu      = '[STR Farrow]     10-bit unsigned fractional interval mu in [0, 1)';
    d.ted_d   = '[STR TED]        Symbol difference wire (cur - prev)';
    d.ted_e   = '[STR TED]        Gardner TED error output e = mid_I*d_I + mid_Q*d_Q';
    d.str_pi  = '[STR PI Filter]  STR loop filter integrator and output (saturating)';
    d.str_kp  = '[STR PI Filter]  STR proportional loop gain Kp';
    d.str_ki  = '[STR PI Filter]  STR integral loop gain Ki';
    d.cprod   = '[Coarse CFO]     Lag-4 conjugate product r[n] * conj(r[n-4])';
    d.cacc    = '[Coarse CFO]     Correlation window complex accumulator (32 symbols)';
    d.cx      = '[Coarse CORDIC]  16-stage vectoring CORDIC X, Y coordinates';
    d.cz      = '[Coarse CORDIC]  16-stage CORDIC angle accumulator Z (turns)';
    d.cfo     = '[Coarse CFO Out] Estimated coarse frequency word (turns/symbol)';
    d.lut     = '[Derotator LUT]  Quarter-wave sine LUT entry (4096 x 16-bit)';
    d.phase   = '[Derotator NCO]  32-bit wrapping NCO phase accumulator theta (turns)';
    d.freq_w  = '[Derotator NCO]  32-bit signed NCO frequency word (turns/symbol)';
    d.rot_out = '[Derotator Out]  Derotated I/Q symbol before external *2 scale';
    d.cos_a   = '[Costas Slicer]  Hard-decision slicer levels (+-d, +-3d)';
    d.cos_e   = '[Costas Phase]   Decision-directed phase error e = y_Q*a_I - y_I*a_Q';
    d.cos_pi  = '[Costas PI]      Costas loop filter integrator and output (saturating)';
    d.cos_kp  = '[Costas PI]      Costas proportional loop gain Kp';
    d.cos_ki  = '[Costas PI]      Costas integral loop gain Ki';
    d.sgn_cnt = '[Costas Quad]    5-bit signed saturating quadrant counters (-16..+15)';
    d.cnt     = '[Wrapper]        16-bit unsigned symbol counter';
    d.lock_m  = '[Lock Detectors] EMA moving-average register for lock detection';
    d.lock_b  = '[Lock Detectors] Leaky-bucket confirmation counter';
end
