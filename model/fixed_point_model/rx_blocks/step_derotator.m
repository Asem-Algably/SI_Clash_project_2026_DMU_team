function [out, st] = step_derotator(in, st, T)
    % STEP_DEROTATOR  Cycle-Accurate Fixed-Point Derotator & 32-bit NCO.
    %
    % Self-contained hardware implementation containing:
    %   1. Frequency Word Registers (coarse_reg + adj_reg)
    %   2. 32-Bit NCO Phase Accumulator (theta in binary turns)
    %   3. 12-Bit Quarter-Wave Sine LUT (4096 entries, uQ0.16)
    %   4. Quadrant Pre-Rotation & Complex Multiplier
    %   5. 2-Cycle Derotator Output Pipeline Shift Register

    R  = T.rd;
    D  = T.derot;
    Ld = T.lat.derot; % 2 cycles

    % =====================================================================
    % 1. ACTIVE-LOW RESET (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.coarse = T.fi(0, 'freq_w');
        st.adj    = T.fi(0, 'freq_w');
        st.fw     = T.fi(0, 'freq_w');
        st.theta  = T.fi(0, 'phase');
        st.dp_val = false(1, Ld);
        st.dp_i   = T.fi(zeros(1, Ld), 'rot_out');
        st.dp_q   = T.fi(zeros(1, Ld), 'rot_out');

        out = derot_drive_outputs(st);
        return;
    end

    st_old     = st;
    coarse_cur = R(st_old.coarse);
    adj_cur    = R(st_old.adj);

    % Latch Coarse Frequency Word from Coarse CFO Estimator
    if in.coarse_valid_i
        coarse_cur   = R(T.fi(in.coarse_word_i, 'freq_w'));
        st.coarse(:) = coarse_cur;
    end

    % Latch Fine Frequency Word from Costas PI Loop Filter
    if in.freq_adj_valid_i
        adj_cur   = R(T.fi(in.freq_adj_i, 'freq_w'));
        st.adj(:) = adj_cur;
    end

    fw_cur   = coarse_cur + adj_cur;
    st.fw(:) = fw_cur;

    new_valid = false;
    new_yi    = T.fi(0, 'rot_out');
    new_yq    = T.fi(0, 'rot_out');
    theta_nx  = st_old.theta;

    % Process Valid Input Symbol from STR
    if in.s_axis_valid_i
        xr = R(T.fi(in.s_axis_i_sym_i, 'str_sym'));
        xi = R(T.fi(in.s_axis_q_sym_i, 'str_sym'));

        % Quarter-Wave Sine LUT Lookup & Quadrant Pre-Rotation
        [new_yi, new_yq] = lut_derotate(xr, xi, st_old.theta, D, T);
        new_valid = true;

        % Advance NCO Phase by Frequency Word
        theta_nx = T.fi(R(theta_nx) + fw_cur, 'phase');
    end

    % One-Cycle Initial Quadrant Phase Ambiguity Correction (k * pi/2)
    if in.phase_adj_valid_i
        pa_word  = R(T.fi(in.phase_adj_i, 'freq_w'));
        theta_nx = T.fi(R(theta_nx) + pa_word, 'phase');
    end
    st.theta(:) = theta_nx;

    % 2-Cycle Output Pipeline Shift Register
    st.dp_val  = [new_valid, st_old.dp_val(1 : end-1)];
    st.dp_i(:) = [R(new_yi), R(st_old.dp_i(1 : end-1))];
    st.dp_q(:) = [R(new_yq), R(st_old.dp_q(1 : end-1))];

    out = derot_drive_outputs(st);
end

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================
function out = derot_drive_outputs(st)
    out.m_axis_valid_o = st.dp_val(end);
    out.m_axis_i_sym_o = st.dp_i(end);
    out.m_axis_q_sym_o = st.dp_q(end);
    out.phase_o        = st.theta;
    out.freq_word_o    = st.fw;
end

function [yi, yq] = lut_derotate(xr, xi, theta, D, T)
    % Extract Top 2 Bits (Quadrant) and Next 12 Bits (LUT Address)
    ti = T.raw32(theta);
    q  = double(bitshift(ti, -30)); % Quadrant 0..3
    a  = double(bitand(bitshift(ti, -(30 - D.addr_bits)), uint32(D.Nq - 1)));

    % Quarter-Wave Midpoint Sampling: s0 = S[a], c0 = S[~a]
    s0 = T.rd(D.lut(a + 1));
    c0 = T.rd(D.lut(D.Nq - a));

    % Pre-Rotation by (-j)^q
    switch q
        case 0,    ur =  xr; ui =  xi;
        case 1,    ur =  xi; ui = -xr;
        case 2,    ur = -xr; ui = -xi;
        otherwise, ur = -xi; ui =  xr;
    end

    % Complex Multiply: (ur + j*ui) * (c0 - j*s0)
    yi = T.fi(ur * c0 + ui * s0, 'rot_out', 'wrap_n');
    yq = T.fi(ui * c0 - ur * s0, 'rot_out', 'wrap_n');
end
