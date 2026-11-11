function [out, st] = step_wrapper_fsm(in, st, T)
    % STEP_WRAPPER_FSM  Cycle-Accurate Top-Level Burst FSM & Output Stage (wrapper.md).
    %
    % States: WAIT_BURST -> ACQUIRE -> COARSE_EST -> LOAD -> COSTAS_ACQ -> TRACK
    % Controls coarse_start_o, costas_mode_o, slicer_qpsk_o, preamble_end_o, and
    % aligns output symbols with lock_detect and fine_cfo_est.

    R   = T.rd;
    E   = T.enc.fsm;
    Lo  = T.lat.wrap_out;
    Lpe = T.wrap.pe_delay + 1;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & INITIALIZATION (~rst_ni)
    % =====================================================================
    if isempty(st) || ~in.rst_ni
        st.state    = uint8(E.WAIT_BURST);
        st.sym_cnt  = T.fi(0, 'cnt', 'sat');
        st.cs       = false;
        st.pe_pipe  = false(1, Lpe);
        st.mode     = uint8(T.enc.mode.HOLD);
        st.slicer_q = true;
        st.cfo_hold = T.fi(0, 'cfo', 'sat');
        st.fine     = T.fi(0, 'freq_w', 'sat');
        st.ld       = false;
        st.ow_val   = false(1, Lo);
        st.ow_i     = T.fi(zeros(1, Lo), 'rot_out', 'sat');
        st.ow_q     = T.fi(zeros(1, Lo), 'rot_out', 'sat');

        out = wrap_drive_outputs(st);
        return;
    end

    % =====================================================================
    % 2. SNAPSHOT INTERNAL STATE
    % =====================================================================
    st_old = st;

    % =====================================================================
    % 3. SYMBOL-GATED BURST FSM (Advances on STR m_axis_valid_o)
    % =====================================================================
    cnt = double(st_old.sym_cnt);
    if in.str_valid
        cnt = cnt + 1;
        st.sym_cnt(:) = cnt;
    end

    state     = double(st_old.state);
    new_state = state;
    new_cs    = false;
    new_pe    = false;

    switch state
        case E.WAIT_BURST
            if in.in_sample_valid
                new_state = E.ACQUIRE;
            end
        case E.ACQUIRE
            if in.str_valid
                if T.burst.fixed_start_sym > 0
                    go = (cnt >= T.burst.fixed_start_sym);
                else
                    go = in.str_lock || (cnt >= T.burst.max_acq);
                end
                if go
                    new_state = E.COARSE_EST;
                    new_cs    = true;
                end
            end
        case E.COARSE_EST
            if in.coarse_valid
                new_state = E.LOAD;
            end
        case E.LOAD
            if in.str_valid
                new_state = E.COSTAS_ACQ;
            end
        case E.COSTAS_ACQ
            if in.str_valid && (cnt >= T.burst.N_pre)
                new_state = E.TRACK;
                new_pe    = true;
            end
        case E.TRACK
            % Remain in TRACK until reset
        otherwise
            new_state = E.WAIT_BURST;
    end

    st.state = uint8(new_state);
    st.cs    = new_cs;

    if new_state == E.COSTAS_ACQ
        st.mode = uint8(T.enc.mode.ACQ);
    elseif new_state == E.TRACK
        st.mode = uint8(T.enc.mode.TRACK);
    else
        st.mode = uint8(T.enc.mode.HOLD);
    end
    st.slicer_q = (new_state ~= E.TRACK);
    st.pe_pipe  = [new_pe, st_old.pe_pipe(1:end-1)];

    % =====================================================================
    % 4. OUTPUT STAGE & TOP-LEVEL STATUS REGISTERS
    % =====================================================================
    if in.coarse_valid
        st.cfo_hold(:) = T.fi(in.coarse_word, 'cfo', 'sat');
    end
    st.fine(:) = R(st_old.cfo_hold) + R(T.fi(in.costas_int, 'freq_w', 'sat'));
    st.ld      = logical(in.str_lock) && logical(in.costas_lock);

    st.ow_val  = [logical(in.derot_valid), st_old.ow_val(1:end-1)];
    st.ow_i(:) = [R(T.fi(in.derot_i, 'rot_out', 'sat')), R(st_old.ow_i(1:end-1))];
    st.ow_q(:) = [R(T.fi(in.derot_q, 'rot_out', 'sat')), R(st_old.ow_q(1:end-1))];

    out = wrap_drive_outputs(st);
end

function out = wrap_drive_outputs(st)
    out.out_sym_valid  = st.ow_val(end);
    out.out_sym_i      = st.ow_i(end);
    out.out_sym_q      = st.ow_q(end);
    out.coarse_cfo_est = st.cfo_hold;
    out.fine_cfo_est   = st.fine;
    out.lock_detect    = st.ld;
    out.coarse_start   = st.cs;
    out.costas_mode    = st.mode;
    out.slicer_qpsk    = st.slicer_q;
    out.preamble_end   = st.pe_pipe(end);
    out.fsm_state      = st.state;
end
