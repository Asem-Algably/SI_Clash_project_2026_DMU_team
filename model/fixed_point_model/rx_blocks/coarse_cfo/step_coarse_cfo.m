function [out, st] = step_coarse_cfo(in, st, T)
    % STEP_COARSE_CFO  Cycle-Accurate Fixed-Point Coarse CFO Estimator (coarse_cfo.md).
    %
    % Mathematical Principles:
    %   1. Delay Line & Conjugation:
    %      Maintains 4-stage shift register (Di, Dq). The 4th stage produces the
    %      conjugate: conj(r[n-4]) = Di(4) - j*Dq(4).
    %   2. Complex Product:
    %      pr + j*pm = r[n] * conj(r[n-4])
    %   3. Correlation Accumulator:
    %      Sums products over window of length WinLen (32 symbols):
    %      R = sum_{n=Lag+1}^{WinLen} r[n] * conj(r[n-Lag])
    %   4. CORDIC Angle Evaluation:
    %      Angle Z = atan2(Im{R}, Re{R}) / (2*pi) in fraction-of-turn (sQ1.26).
    %   5. Frequency Word Scaling:
    %      f_coarse = Z / Lag = Z >>> 2 in turns per symbol (sQ-1.24).
    %
    % Hardware Datapath:
    %   All registers use pure 2's-complement wrapping with sized MSB guard bits:
    %   - cprod : 22-bit sQ2.19
    %   - cacc  : 30-bit sQ8.21
    %   - cx    : 32-bit sQ9.22 (CORDIC X/Y)
    %   - cz    : 28-bit sQ1.26 (CORDIC angle in turns)
    %   - cfo   : 24-bit sQ-1.24 (estimate out)

    R  = T.rd;
    C  = T.coarse;
    Lc = T.lat.coarse;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & REGISTERS INITIALIZATION (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.Di     = T.fi(zeros(1, 4), 'str_sym');
        st.Dq     = T.fi(zeros(1, 4), 'str_sym');
        st.active = false;
        st.cnt    = T.fi(0, 'cnt');
        st.Ar     = T.fi(0, 'cacc');
        st.Ai     = T.fi(0, 'cacc');
        st.cf_val = false(1, Lc);
        st.cf_w   = T.fi(zeros(1, Lc), 'cfo');

        out.m_axis_valid_o = false;
        out.m_axis_cfo_o   = st.cf_w(end);
        return;
    end

    st_old    = st;
    act       = st_old.active;
    cnt       = double(st_old.cnt);
    Ar        = R(st_old.Ar);
    Ai        = R(st_old.Ai);
    new_valid = false;
    new_word  = T.fi(0, 'cfo');

    if in.start_i
        act = true;
        cnt = 0;
        Ar  = R(T.fi(0, 'cacc'));
        Ai  = R(T.fi(0, 'cacc'));
    end

    if in.s_axis_valid_i
        ri  = R(T.fi(in.s_axis_i_sym_i, 'str_sym'));
        rq  = R(T.fi(in.s_axis_q_sym_i, 'str_sym'));
        d4i = R(st_old.Di(4));
        d4q = R(st_old.Dq(4));

        if act
            cnt = cnt + 1;
            if cnt > C.lag
                pr = T.fi(ri * d4i - rq * d4q, 'cprod');
                pm = T.fi(ri * d4q + rq * d4i, 'cprod');
                Ar = R(T.fi(Ar + R(pr), 'cacc'));
                Ai = R(T.fi(Ai + R(pm), 'cacc'));
            end
            if cnt >= C.win_len
                act       = false;
                new_valid = true;
                new_word  = fxp_cordic_angle(Ar, Ai, T);
            end
        end

        st.Di(:) = [ri, R(st_old.Di(1:3))];
        st.Dq(:) = [rq, R(st_old.Dq(1:2)), -R(st_old.Dq(3))];
    end

    st.active  = act;
    st.cnt(:)  = cnt;
    st.Ar(:)   = Ar;
    st.Ai(:)   = Ai;
    st.cf_val  = [new_valid,   st_old.cf_val(1:end-1)];
    st.cf_w(:) = [R(new_word), R(st_old.cf_w(1:end-1))];

    out.m_axis_valid_o = st.cf_val(end);
    out.m_axis_cfo_o   = st.cf_w(end);
    if in.force_cfo_en_i
        out.m_axis_cfo_o = T.fi(in.force_cfo_i, 'cfo');
    end
end

function f = fxp_cordic_angle(x, y, T)
    R  = T.rd;
    Cc = T.coarse;
    xx = T.fi(x, 'cx');
    yy = T.fi(y, 'cx');
    z  = T.fi(0, 'cz');

    if R(xx) < 0
        yneg = (R(yy) < 0);
        xx   = T.fi(-R(xx), 'cx');
        yy   = T.fi(-R(yy), 'cx');
        if yneg
            z = T.fi(-0.5, 'cz');
        else
            z = T.fi(0.5,  'cz');
        end
    end

    for i = 0 : Cc.cordic_iter - 1
        dx = bitsra(R(yy), i);
        dy = bitsra(R(xx), i);
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

    f = T.fi(bitsra(R(z), Cc.lag_shift), 'cfo');
end
