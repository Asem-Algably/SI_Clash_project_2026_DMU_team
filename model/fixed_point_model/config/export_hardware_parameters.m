function export_hardware_parameters(T, filename)
    % EXPORT_HARDWARE_PARAMETERS  Exports key hardware parameters, loop gains (Kp, Ki),
    % lock thresholds, and register bit-widths (with true fixed-point hex & RTL descriptions)
    % into a text report inside the config folder.
    %
    % Inputs:
    %   T        - Hardware definitions struct from get_hw_types_and_cfg()
    %   filename - (Optional) Destination text report path; defaults to config/hw_parameters_exported.txt

    default_file = fullfile(fileparts(mfilename('fullpath')), 'hw_parameters_exported.txt');
    if exist('filename', 'var') == 0
        filename = default_file;
    end

    fid = fopen(filename, 'w');
    if fid == -1
        error('export_hw:io', 'Could not open file %s for writing.', filename);
    end

    const_info = get_constellation_map(T.cfg.mod_type, T.cfg.norm_mode);
    row_idx    = min(T.cfg.mod_type, 1) + 1;

    fprintf(fid, '==================================================================================================================\n');
    fprintf(fid, '  SI-CLASH HARDWARE PARAMETER & REGISTER EXPORT REPORT (For RTL / Hardware Designers)\n');
    fprintf(fid, '==================================================================================================================\n');
    fprintf(fid, '  Modulation Type : %s (mod_type = %d)\n', const_info.name, T.cfg.mod_type);
    fprintf(fid, '  Normalisation   : %s\n', T.cfg.norm_mode);
    fprintf(fid, '  Input Scale (g) : %.4f (Wrapper >>1 shift at input, <<1 shift at output)\n', T.in_scale);
    fprintf(fid, '  Preamble Sched  : N_A = %d, N_B = %d, N_C = %d (Total = %d symbols)\n', ...
        T.burst.N_A, T.burst.N_B, T.burst.N_C, T.burst.N_pre);
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  1. FIXED-POINT PI LOOP FILTER GAINS (True Fixed-Point Stored Integer & Hex)\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');

    [str_kp_int, str_kp_hex, str_kp_fmt] = fxp_val_to_hw_str(T.str.kp, T.w.str_kp);
    [str_ki_int, str_ki_hex, str_ki_fmt] = fxp_val_to_hw_str(T.str.ki, T.w.str_ki);
    fprintf(fid, '  STR Loop Filter (str.md | Bn_Ts = %.3f, zeta = %.3f):\n', T.cfg.str.Bn_Ts, T.cfg.str.zeta);
    fprintf(fid, '    STR Kp    (%s) : Real = %12.8f | Int = %10d | RTL Hex = %s\n', ...
        str_kp_fmt, double(T.str.kp), str_kp_int, str_kp_hex);
    fprintf(fid, '    STR Ki    (%s) : Real = %12.8f | Int = %10d | RTL Hex = %s\n', ...
        str_ki_fmt, double(T.str.ki), str_ki_int, str_ki_hex);
    fprintf(fid, '\n');

    [cos_kp_int, cos_kp_hex, cos_kp_fmt] = fxp_val_to_hw_str(T.costas.kp{row_idx}, T.w.cos_kp);
    [cos_ki_int, cos_ki_hex, cos_ki_fmt] = fxp_val_to_hw_str(T.costas.ki{row_idx}, T.w.cos_ki);
    fprintf(fid, '  Costas Loop Filter (costas.md | Bn_Ts = %.3f, zeta = %.3f, Single Fixed Gain):\n', ...
        T.cfg.costas.Bn_Ts, T.cfg.costas.zeta);
    fprintf(fid, '    Costas Kp (%s) : Real = %12.8f | Int = %10d | RTL Hex = %s\n', ...
        cos_kp_fmt, double(T.costas.kp{row_idx}), cos_kp_int, cos_kp_hex);
    fprintf(fid, '    Costas Ki (%s) : Real = %12.8f | Int = %10d | RTL Hex = %s\n', ...
        cos_ki_fmt, double(T.costas.ki{row_idx}), cos_ki_int, cos_ki_hex);
    fprintf(fid, '\n');

    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  2. LOCK DETECTOR & QUADRANT THRESHOLDS (True Fixed-Point Stored Integer & Hex)\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    [s_ent_int, s_ent_hex, lk_fmt] = fxp_val_to_hw_str(T.str.lock.thr_enter, T.w.lock_m);
    [s_ext_int, s_ext_hex, ~]      = fxp_val_to_hw_str(T.str.lock.thr_exit,  T.w.lock_m);
    fprintf(fid, '  STR Lock Detector (str.md | ema_shift = %d, confirm_cnt = %d):\n', ...
        T.str.lock.ema_shift, T.str.lock.confirm);
    fprintf(fid, '    str_thr_enter    (%s) : Real = %10.6f | Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(T.str.lock.thr_enter), s_ent_int, s_ent_hex);
    fprintf(fid, '    str_thr_exit     (%s) : Real = %10.6f | Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(T.str.lock.thr_exit),  s_ext_int, s_ext_hex);
    fprintf(fid, '\n');

    [c_ent_int, c_ent_hex, ~] = fxp_val_to_hw_str(T.costas.lock_pub(row_idx).thr_enter, T.w.lock_m);
    [c_ext_int, c_ext_hex, ~] = fxp_val_to_hw_str(T.costas.lock_pub(row_idx).thr_exit,  T.w.lock_m);
    fprintf(fid, '  Costas Lock Detector (costas.md | ema_shift = %d, confirm_cnt = %d, sgn_cnt = [%d..+%d]):\n', ...
        T.costas.lock_pub(row_idx).ema_shift, T.costas.lock_pub(row_idx).confirm, ...
        T.costas.cnt_full_neg, T.costas.cnt_full_pos);
    fprintf(fid, '    costas_thr_enter (%s) : Real = %10.6f | Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(T.costas.lock_pub(row_idx).thr_enter), c_ent_int, c_ent_hex);
    fprintf(fid, '    costas_thr_exit  (%s) : Real = %10.6f | Int = %10d | RTL Hex = %s\n', ...
        lk_fmt, double(T.costas.lock_pub(row_idx).thr_exit),  c_ext_int, c_ext_hex);
    fprintf(fid, '\n');

    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  3. HARDWARE REGISTER & BUS BIT-WIDTHS [Signed, WordLength, FractionLength]\n');
    fprintf(fid, '------------------------------------------------------------------------------------------------------------------\n');
    fprintf(fid, '  %-10s | %-28s | %-10s | %s\n', 'Bus Name', 'Fixed-Point Spec', 'Q-Format', 'Subsystem & Hardware Signal Description');
    fprintf(fid, '  %s\n', repmat('-', 1, 110));

    desc_map = get_bus_descriptions();
    fnames   = fieldnames(T.w);
    for i = 1:numel(fnames)
        bname = fnames{i};
        spec  = T.w.(bname);
        sgn_s = 'Unsigned'; if spec(1) == 1, sgn_s = 'Signed  '; end
        int_b = spec(2) - spec(1) - spec(3);
        if spec(1) == 1
            q_str = sprintf('sQ%d.%d', int_b, spec(3));
        else
            q_str = sprintf('uQ%d.%d', int_b, spec(3));
        end
        if isfield(desc_map, bname)
            d_str = desc_map.(bname);
        else
            d_str = 'Internal datapath register';
        end
        fprintf(fid, '  %-10s | [%s, WL=%2d, FL=%2d] | %-10s | %s\n', ...
            bname, sgn_s, spec(2), spec(3), q_str, d_str);
    end
    fprintf(fid, '==================================================================================================================\n');
    fclose(fid);

    fprintf('[EXPORT] Hardware parameters successfully exported to: %s\n', filename);
end

function [stored_int, rtl_hex, fmt_str] = fxp_val_to_hw_str(val, spec)
    % Converts a fixed-point value and [Signed, WL, FL] spec into its exact RTL integer and Verilog hex literal
    sgn = spec(1);
    wl  = spec(2);
    fl  = spec(3);
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

function d = get_bus_descriptions()
    d.in      = '[Top / STR In]       Input I/Q sample port (in_sample_i/q) after wrapper >>1 shift';
    d.str_sym = '[STR -> Derot/CFO]   Interpolated I/Q symbol output from Farrow filter (m_axis_i/q_sym_o)';
    d.fv      = '[STR Farrow]         Farrow polynomial coefficients v1, v2 (4-tap sum with +3 MSB guard bits)';
    d.fh      = '[STR Farrow]         Farrow Horner MAC intermediate stage register (v2*mu + v1)';
    d.M       = '[STR Controller]     Modulo-1 decrementing timing phase counter M and step register W (wraps mod 1)';
    d.M_s     = '[STR Controller]     Signed 25-bit combinational difference wire (M - W, M - 0.25, M - 0.75)';
    d.eta     = '[STR Controller]     Distance above strobe boundary (M - 0.25 for cur_strobe, M - 0.75 for mid_strobe)';
    d.pi_mu   = '[STR Controller]     STR PI loop filter output routed to linear mu multiplier (4*eta - 16*eta*pi)';
    d.mu      = '[STR Farrow]         10-bit unsigned fractional interpolation interval mu in [0, 1)';
    d.ted_d   = '[STR Gardner TED]    Symbol difference wire (Re/Im{cur} - Re/Im{prev})';
    d.ted_e   = '[STR Gardner TED]    Timing error detector output e = mid_I*(cur_I-prev_I) + mid_Q*(cur_Q-prev_Q)';
    d.str_pi  = '[STR PI Filter]      STR loop filter integrator register and saturated control output v_pi';
    d.str_kp  = '[STR PI Filter]      STR proportional gain constant Kp';
    d.str_ki  = '[STR PI Filter]      STR integral gain constant Ki';
    d.cprod   = '[Coarse CFO]         Lag-4 delayed-conjugate product r[n] * conj(r[n-4])';
    d.cacc    = '[Coarse CFO]         Correlation window complex accumulator (sums N_win - 4 products)';
    d.cx      = '[Coarse CFO CORDIC]  16-stage vectoring CORDIC X and Y coordinate registers';
    d.cz      = '[Coarse CFO CORDIC]  16-stage vectoring CORDIC angle accumulator Z and atan LUT (in turns)';
    d.cfo     = '[Coarse CFO Out]     Estimated coarse CFO word (m_axis_cfo_o = Z >> 2, in turns/symbol)';
    d.lut     = '[Derotator LUT]      Quarter-wave sine LUT entry (4096 x 16-bit unsigned ROM)';
    d.phase   = '[Derotator NCO]      32-bit wrapping NCO phase accumulator theta (binary radians / turns)';
    d.freq_w  = '[Derotator / Top]    32-bit signed NCO frequency word (coarse_cfo + costas_adj) and fine_cfo_est';
    d.rot_out = '[Derotator / Top Out] Derotated I/Q output symbol (out_sym_i/q, Q1.15 before external <<1 shift)';
    d.cos_a   = '[Costas Slicer]      Hard-decision QPSK / 16-QAM slicer output levels (+-d, +-3d) and 2d threshold';
    d.cos_e   = '[Costas Phase Det]   Decision-directed phase error e = y_Q * a_I - y_I * a_Q';
    d.cos_pi  = '[Costas PI Filter]   Costas loop filter integrator register (int_o) and output (freq_adj_o)';
    d.cos_kp  = '[Costas PI Filter]   Costas proportional gain constant Kp';
    d.cos_ki  = '[Costas PI Filter]   Costas integral gain constant Ki';
    d.sgn_cnt = '[Costas Quad Check]  5-bit signed saturating I/Q slicer sign counters (-16 to +15) in Phase C';
    d.cnt     = '[Wrapper / Control]  16-bit unsigned symbol counter for burst FSM and coarse window timing';
    d.lock_m  = '[Lock Detectors]     EMA moving-average register m <- m + (|e| - m)*2^-4 for STR and Costas lock';
    d.lock_b  = '[Lock Detectors]     8-bit unsigned leaky-bucket confirmation counter (+1 good, -2 bad)';
end
