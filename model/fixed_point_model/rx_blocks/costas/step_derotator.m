function [out, st] = step_derotator(in, st, T)
    % STEP_DEROTATOR  Cycle-Accurate & Interface-Accurate Derotator & 32-bit NCO (derotator.md).
    %
    % Ports (in):
    %   rst_ni, s_axis_valid_i, s_axis_i_sym_i, s_axis_q_sym_i (Q2.14),
    %   coarse_valid_i, coarse_word_i (24-bit), freq_adj_valid_i, freq_adj_i,
    %   phase_adj_valid_i, phase_adj_i (32-bit), force_freq_en_i, force_freq_i
    % Ports (out):
    %   m_axis_valid_o, m_axis_i_sym_o, m_axis_q_sym_o (Q1.15 / Q2.14 scaled),
    %   phase_o (32-bit), freq_word_o (32-bit)

    R  = T.rd;
    D  = T.derot;
    Ld = T.lat.derot;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & INITIALIZATION (~rst_ni)
    % =====================================================================
    if isempty(st) || ~in.rst_ni
        st.coarse = T.fi(0, 'freq_w', 'sat');      % Coarse frequency word register (0 before LOAD)
        st.adj    = T.fi(0, 'freq_w', 'sat');      % Costas PI frequency correction
        st.fw     = T.fi(0, 'freq_w', 'sat');      % Total frequency word = coarse + adj
        st.theta  = T.fi(0, 'phase',  'wrap');     % 32-bit wrapping NCO phase in turns [0, 1)
        st.dp_val = false(1, Ld);
        st.dp_i   = T.fi(zeros(1, Ld), 'rot_out', 'sat');
        st.dp_q   = T.fi(zeros(1, Ld), 'rot_out', 'sat');
        st.dp_ph  = zeros(1, Ld);                  % Diagnostic phase log aligned with symbol

        out = derot_drive_outputs(st);
        return;
    end

    % =====================================================================
    % 2. SNAPSHOT INTERNAL STATE
    % =====================================================================
    st_old = st;

    % =====================================================================
    % 3. CLOCK-RATE CONTROL STROBES (coarse_valid_i, freq_adj_valid_i, phase_adj_valid_i)
    % =====================================================================
    coarse_cur = R(st_old.coarse);
    adj_cur    = R(st_old.adj);

    if in.coarse_valid_i
        coarse_cur   = R(T.fi(in.coarse_word_i, 'freq_w', 'sat'));
        st.coarse(:) = coarse_cur;
    end
    if in.freq_adj_valid_i
        adj_cur   = R(T.fi(in.freq_adj_i, 'freq_w', 'sat'));
        st.adj(:) = adj_cur;
    end

    if in.force_freq_en_i
        fw_cur = R(T.fi(in.force_freq_i, 'freq_w', 'sat'));
    else
        fw_cur = coarse_cur + adj_cur;
    end
    st.fw(:) = fw_cur;

    % =====================================================================
    % 4. SYMBOL-RATE ROTATION & NCO ACCUMULATION (s_axis_valid_i)
    % =====================================================================
    new_valid = false;
    new_yi    = T.fi(0, 'rot_out', 'sat');
    new_yq    = T.fi(0, 'rot_out', 'sat');
    theta_cur = R(st_old.theta);
    theta_nx  = st_old.theta;
    ph_rad    = mod(double(theta_cur) * 2 * pi + pi, 2 * pi) - pi;

    if in.s_axis_valid_i
        xr = R(T.fi(in.s_axis_i_sym_i, 'str_sym', 'sat'));
        xi = R(T.fi(in.s_axis_q_sym_i, 'str_sym', 'sat'));

        if strcmpi(D.mode, 'ideal')
            z_rot  = (double(xr) + 1j * double(xi)) * exp(-1j * ph_rad);
            new_yi = T.fi(real(z_rot), 'rot_out', 'sat_n');
            new_yq = T.fi(imag(z_rot), 'rot_out', 'sat_n');
        else
            % Quarter-wave LUT lookup + quadrant pre-rotation (derotator.md Section 3)
            ti = T.raw32(st_old.theta);
            q  = double(bitshift(ti, -30));
            a  = double(bitand(bitshift(ti, -(30 - D.addr_bits)), uint32(D.Nq - 1)));
            s0 = R(D.lut(a + 1));
            c0 = R(D.lut(D.Nq - a));

            switch q
                case 0,    ur =  xr; ui =  xi;
                case 1,    ur =  xi; ui = -xr;
                case 2,    ur = -xr; ui = -xi;
                otherwise, ur = -xi; ui =  xr;
            end
            new_yi = T.fi(ur * c0 + ui * s0, 'rot_out', 'sat_n');
            new_yq = T.fi(ui * c0 - ur * s0, 'rot_out', 'sat_n');
        end
        new_valid = true;

        % Pure fi 32-bit wrapping NCO phase update (theta + signed fw_cur)
        theta_nx = T.wrapf(T.fi(R(theta_nx) + fw_cur, 'phase', 'wrap'));
    end

    if in.phase_adj_valid_i
        % Pure fi one-time quadrant ambiguity correction k * pi/2 (in turns: k * 0.25)
        pa_s     = R(T.fi(in.phase_adj_i, 'freq_w', 'wrap'));
        theta_nx = T.wrapf(T.fi(R(theta_nx) + pa_s, 'phase', 'wrap'));
    end
    st.theta(:) = theta_nx;

    % =====================================================================
    % 5. CLOCK-RATE PIPELINE ADVANCE (T.lat.derot clocks)
    % =====================================================================
    st.dp_val  = [new_valid, st_old.dp_val(1:end-1)];
    st.dp_i(:) = [R(new_yi), R(st_old.dp_i(1:end-1))];
    st.dp_q(:) = [R(new_yq), R(st_old.dp_q(1:end-1))];
    st.dp_ph   = [ph_rad,    st_old.dp_ph(1:end-1)];

    out = derot_drive_outputs(st);
end

function out = derot_drive_outputs(st)
    out.m_axis_valid_o = st.dp_val(end);
    out.m_axis_i_sym_o = st.dp_i(end);
    out.m_axis_q_sym_o = st.dp_q(end);
    out.phase_o        = st.theta;
    out.freq_word_o    = st.fw;
    out.phase_rad_o    = st.dp_ph(end);
end
