function [out, st] = step_coarse_cfo(in, st, T)
    % STEP_COARSE_CFO  Cycle-Accurate Fixed-Point Coarse CFO Estimator.
    %
    % Self-contained hardware implementation containing:
    %   1. 4-Stage Conjugate Delay Line (negates Q on stage 4)
    %   2. Lag-4 Complex Multiplier: r[n] * conj(r[n-4])
    %   3. 32-Symbol Correlation Accumulator (30-bit sQ8.21)
    %   4. 16-Stage Vectoring CORDIC Angle Solver (sQ1.26 turns)
    %   5. 16-Cycle CORDIC IP Pipeline Shift Register

    R  = T.rd;
    Lc = T.lat.coarse; % 20 entries = 19 clock cycles delay, matching RTL cordic_angle

    % =====================================================================
    % 1. ACTIVE-LOW RESET (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.Di         = T.fi(zeros(1, 4), 'str_sym');
        st.Dq         = T.fi(zeros(1, 4), 'str_sym');
        st.active     = false;
        st.start_prev = false;
        st.cnt        = T.fi(0, 'cnt');
        st.Ar         = T.fi(0, 'cacc');
        st.Ai         = T.fi(0, 'cacc');
        st.cf_val     = false(1, Lc);
        st.cf_w       = T.fi(zeros(1, Lc), 'cfo');

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

    % Rising-edge trigger on start_i (supports level enable from burst_ctrl)
    start_prev = isfield(st_old, 'start_prev') && logical(st_old.start_prev);
    st.start_prev = logical(in.start_i);
    if in.start_i && ~start_prev
        act = true;
        cnt = 0;
        Ar  = R(T.fi(0, 'cacc'));
        Ai  = R(T.fi(0, 'cacc'));
    end

    % Process Valid Input Symbol from STR
    if in.s_axis_valid_i
        ri  = R(T.fi(in.s_axis_i_sym_i, 'str_sym'));
        rq  = R(T.fi(in.s_axis_q_sym_i, 'str_sym'));
        d4i = R(st_old.Di(4));
        d4q = R(st_old.Dq(4));

        if act
            cnt = cnt + 1;
            if cnt > 4 % After lag-4 delay line is primed
                % Lag-4 complex product: r[n] * conj(r[n-4])
                pr = T.fi(ri * d4i - rq * d4q, 'cprod');
                pm = T.fi(ri * d4q + rq * d4i, 'cprod');
                Ar = R(T.fi(Ar + R(pr), 'cacc'));
                Ai = R(T.fi(Ai + R(pm), 'cacc'));
            end

            % Accumulate over 32 symbols (cnt reaches 32)
            if cnt >= 32
                act       = false;
                new_valid = true;
                new_word  = cordic_angle_solver(Ar, Ai, T);
            end
        end

        % Update conjugate delay line (negates Q into 4th stage)
        st.Di(:) = [ri, R(st_old.Di(1:3))];
        st.Dq(:) = [rq, R(st_old.Dq(1:2)), -R(st_old.Dq(3))];
    end

    st.active  = act;
    st.cnt(:)  = cnt;
    st.Ar(:)   = Ar;
    st.Ai(:)   = Ai;

    % 16-Cycle CORDIC IP Pipeline Shift Register
    st.cf_val  = [new_valid,   st_old.cf_val(1 : end-1)];
    st.cf_w(:) = [R(new_word), R(st_old.cf_w(1 : end-1))];

    out.m_axis_valid_o = st.cf_val(end);
    out.m_axis_cfo_o   = st.cf_w(end);
    if isfield(in, 'force_cfo_en_i') && in.force_cfo_en_i
        out.m_axis_cfo_o = T.fi(in.force_cfo_i, 'cfo');
    end
end

% =========================================================================
% LOCAL HELPER: 16-STAGE VECTORING CORDIC IP
% =========================================================================
function f = cordic_angle_solver(x, y, T)
    % 16-Stage Vectoring CORDIC Angle Evaluation matching RTL cordic_angle.sv.
    % Evaluates angle in fraction-of-turn, then divides by lag D=4.
    x_int = int64(storedInteger(x));
    y_int = int64(storedInteger(y));

    % Save original signs and take absolute values
    sign_x = (x_int < 0);
    sign_y = (y_int < 0);
    if sign_x, x_q = -x_int; else, x_q = x_int; end
    if sign_y, y_q = -y_int; else, y_q = y_int; end

    % Precalculated atan table matching cordic_angle.sv atan_lut
    atan_lut_int = int64([ ...
        2097152, 1237935, 653967, 331868, ...
        166564,   83364,  41688,  20844, ...
         10422,    5211,   2605,   1302, ...
           651,     325,    162,     81 ]);

    z_q = int64(0);
    for i = 0:15
        dx = bitsra(y_q, i);
        dy = bitsra(x_q, i);
        if y_q > 0
            x_q = x_q + dx;
            y_q = y_q - dy;
            z_q = z_q + atan_lut_int(i + 1);
        else
            x_q = x_q - dx;
            y_q = y_q + dy;
            z_q = z_q - atan_lut_int(i + 1);
        end
    end

    % Quadrant correction matching cordic_angle.sv StDone
    if ~sign_x && ~sign_y
        angle_o = z_q;
    elseif ~sign_x && sign_y
        angle_o = -z_q;
    elseif sign_x && ~sign_y
        angle_o = int64(8388607) - z_q;
    else
        angle_o = -int64(8388607) + z_q;
    end

    % Divide by lag D=4 matching coarse_cfo_core.sv: angle_out >>> 2
    cfo_int = bitsra(angle_o, 2);

    % Convert 24-bit integer (2^24 = 1 turn) to fi('cfo')
    cfo_turns = double(cfo_int) * (2^-24);
    f = T.fi(cfo_turns, 'cfo');
end
