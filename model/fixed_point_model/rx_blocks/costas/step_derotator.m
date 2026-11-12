function [out, st] = step_derotator(in, st, T)
    % STEP_DEROTATOR  Cycle-Accurate Fixed-Point Derotator & 32-bit NCO (derotator.md).
    %
    % Hardware Datapath:
    %   1. Frequency Word Register:
    %      fw = coarse_word (latched on coarse_valid_i) + freq_adj (from Costas PI filter).
    %   2. 32-Bit NCO Phase Accumulator:
    %      theta <- theta + fw on every valid input symbol (wraps mod 1.0 = 2^32).
    %      On phase_adj_valid_i, adds initial quadrant ambiguity correction k*pi/2.
    %   3. Quarter-Wave Sine LUT (4096 entries):
    %      Upper 2 bits of theta select quadrant [0..3]. Bits [29:18] index the ROM:
    %      s0 = S[a], c0 = S[~a].
    %   4. Complex Multiplier:
    %      y = x * exp(-j*theta) = (x_re*cos + x_im*sin) + j*(x_im*cos - x_re*sin).
    %
    % All registers use pure 2's-complement wrapping with MSB guard bits.

    R  = T.rd;
    D  = T.derot;
    Ld = T.lat.derot;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & REGISTERS INITIALIZATION (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.coarse = T.fi(0, 'freq_w');
        st.adj    = T.fi(0, 'freq_w');
        st.fw     = T.fi(0, 'freq_w');
        st.theta  = T.fi(0, 'phase');
        st.dp_val = false(1, Ld);
        st.dp_i   = T.fi(zeros(1, Ld), 'rot_out');
        st.dp_q   = T.fi(zeros(1, Ld), 'rot_out');
        st.dp_ph  = zeros(1, Ld);

        out = derot_drive_outputs(st);
        return;
    end

    st_old     = st;
    coarse_cur = R(st_old.coarse);
    adj_cur    = R(st_old.adj);

    if in.coarse_valid_i
        coarse_cur   = R(T.fi(in.coarse_word_i, 'freq_w'));
        st.coarse(:) = coarse_cur;
    end
    if in.freq_adj_valid_i
        adj_cur   = R(T.fi(in.freq_adj_i, 'freq_w'));
        st.adj(:) = adj_cur;
    end

    if in.force_freq_en_i
        fw_cur = R(T.fi(in.force_freq_i, 'freq_w'));
    else
        fw_cur = coarse_cur + adj_cur;
    end
    st.fw(:) = fw_cur;

    new_valid = false;
    new_yi    = T.fi(0, 'rot_out');
    new_yq    = T.fi(0, 'rot_out');
    theta_cur = R(st_old.theta);
    theta_nx  = st_old.theta;
    ph_rad    = mod(double(theta_cur) * 2 * pi + pi, 2 * pi) - pi;

    if in.s_axis_valid_i
        xr = R(T.fi(in.s_axis_i_sym_i, 'str_sym'));
        xi = R(T.fi(in.s_axis_q_sym_i, 'str_sym'));

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
        new_yi = T.fi(ur * c0 + ui * s0, 'rot_out', 'wrap_n');
        new_yq = T.fi(ui * c0 - ur * s0, 'rot_out', 'wrap_n');
        new_valid = true;

        theta_nx = T.fi(R(theta_nx) + fw_cur, 'phase');
    end

    if in.phase_adj_valid_i
        pa_s     = R(T.fi(in.phase_adj_i, 'freq_w'));
        theta_nx = T.fi(R(theta_nx) + pa_s, 'phase');
    end
    st.theta(:) = theta_nx;

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
