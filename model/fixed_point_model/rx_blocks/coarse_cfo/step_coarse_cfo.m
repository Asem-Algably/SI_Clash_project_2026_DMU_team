function [out, st] = step_coarse_cfo(in, st, T)
    % STEP_COARSE_CFO  Cycle-Accurate & Interface-Accurate Coarse CFO Estimator (coarse_cfo.md).
    %
    % Ports (in):
    %   rst_ni, start_i, s_axis_valid_i, s_axis_i_sym_i, s_axis_q_sym_i (Q2.14),
    %   force_cfo_en_i, force_cfo_i
    % Ports (out):
    %   m_axis_valid_o (1-cycle pulse), m_axis_cfo_o (24-bit signed, turns/symbol)

    R  = T.rd;
    C  = T.coarse;
    Lc = T.lat.coarse;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & INITIALIZATION (~rst_ni)
    % =====================================================================
    if isempty(st) || ~in.rst_ni
        st.Di     = T.fi(zeros(1, 4), 'str_sym', 'sat'); % 4-symbol delay line (D4 stores conjugate)
        st.Dq     = T.fi(zeros(1, 4), 'str_sym', 'sat');
        st.active = false;
        st.cnt    = T.fi(0, 'cnt', 'sat');
        st.Ar     = T.fi(0, 'cacc', 'sat');
        st.Ai     = T.fi(0, 'cacc', 'sat');
        st.cf_val = false(1, Lc);                        % Lumped CORDIC latency shift register
        st.cf_w   = T.fi(zeros(1, Lc), 'cfo', 'sat');

        out.m_axis_valid_o = false;
        out.m_axis_cfo_o   = st.cf_w(end);
        return;
    end

    % =====================================================================
    % 2. SNAPSHOT INTERNAL STATE
    % =====================================================================
    st_old = st;

    % =====================================================================
    % 3. STROBE-GATED ACCUMULATOR & CORDIC LAUNCH (s_axis_valid_i)
    % =====================================================================
    act = st_old.active;
    cnt = double(st_old.cnt);
    Ar  = R(st_old.Ar);
    Ai  = R(st_old.Ai);
    new_valid = false;
    new_word  = T.fi(0, 'cfo', 'sat');

    if in.start_i
        act = true;
        cnt = 0;
        Ar  = 0;
        Ai  = 0;
    end

    if in.s_axis_valid_i
        ri  = R(T.fi(in.s_axis_i_sym_i, 'str_sym', 'sat'));
        rq  = R(T.fi(in.s_axis_q_sym_i, 'str_sym', 'sat'));
        d4i = R(st_old.Di(4));
        d4q = R(st_old.Dq(4)); % Already conjugated (-Q(n-4)) when loaded into D4

        if act
            cnt = cnt + 1;
            if cnt > C.lag
                % Complex product r[n] * conj(r[n-4])
                pr = T.fi(ri * d4i - rq * d4q, 'cprod', 'sat');
                pm = T.fi(ri * d4q + rq * d4i, 'cprod', 'sat');
                Ar = R(T.fi(Ar + R(pr), 'cacc', 'sat'));
                Ai = R(T.fi(Ai + R(pm), 'cacc', 'sat'));
            end
            if cnt >= C.win_len
                act       = false;
                new_valid = true;
                new_word  = fxp_cordic_angle(Ar, Ai, T);
            end
        end

        % Advance symbol-rate delay chain (D4 loads -Q3)
        st.Di(:) = [ri, R(st_old.Di(1:3))];
        st.Dq(:) = [rq, R(st_old.Dq(1:2)), -R(st_old.Dq(3))];
    end

    st.active = act;
    st.cnt(:) = cnt;
    st.Ar(:)  = Ar;
    st.Ai(:)  = Ai;

    % =====================================================================
    % 4. CLOCK-RATE CORDIC PIPELINE SHIFT (Advances on EVERY clk_i)
    % =====================================================================
    st.cf_val  = [new_valid,   st_old.cf_val(1:end-1)];
    st.cf_w(:) = [R(new_word), R(st_old.cf_w(1:end-1))];

    out.m_axis_valid_o = st.cf_val(end);
    out.m_axis_cfo_o   = st.cf_w(end);
    if in.force_cfo_en_i
        out.m_axis_cfo_o = T.fi(in.force_cfo_i, 'cfo', 'sat');
    end
end

function f = fxp_cordic_angle(x, y, T)
    % Computes angle(x + j*y) / (2*pi*4) in turns/symbol using 16-stage vectoring CORDIC
    R  = T.rd;
    Cc = T.coarse;
    if strcmpi(Cc.angle_mode, 'atan2')
        ang_turns = atan2(double(y), double(x)) / (2 * pi);
        f = T.fi(ang_turns / Cc.lag, 'cfo', 'sat');
        return;
    end

    xx = T.fi(x, 'cx', 'sat');
    yy = T.fi(y, 'cx', 'sat');
    z  = T.fi(0, 'cz', 'sat');

    % Half-plane rotation into right half-plane (x >= 0)
    if R(xx) < 0
        yneg = (R(yy) < 0);
        xx   = T.fi(-R(xx), 'cx', 'sat');
        yy   = T.fi(-R(yy), 'cx', 'sat');
        if yneg
            z = T.fi(-0.5, 'cz', 'sat');
        else
            z = T.fi(0.5,  'cz', 'sat');
        end
    end

    for i = 0 : Cc.cordic_iter - 1
        dx = pow2(R(yy), -i);
        dy = pow2(R(xx), -i);
        at = R(Cc.atan(i + 1));
        if R(yy) >= 0
            xn = R(xx) + dx;
            yn = R(yy) - dy;
            zn = R(z)  + at;
        else
            xn = R(xx) - dx;
            yn = R(yy) + dy;
            zn = R(z)  - at;
        end
        xx(:) = xn;
        yy(:) = yn;
        z(:)  = zn;
    end

    % Right-shift by 2 (>> 2) to divide by lag D = 4
    f = T.fi(pow2(R(z), -Cc.lag_shift), 'cfo', 'sat');
end
