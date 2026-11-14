function [out, st] = step_wrapper_fsm(in, st, T)
    % STEP_WRAPPER_FSM  Cycle-Accurate Top-Level Burst FSM & Output Register Stage.
    %
    % 6-State Burst FSM:
    %   WAIT_BURST (0) -> ACQUIRE (1) -> COARSE_EST (2) -> LOAD (3) -> COSTAS_ACQ (4) -> TRACK (5)
    %
    % State Transitions (Dual Lock / Preamble Timeout):
    %   - ACQUIRE -> COARSE_EST : str_lock || cnt >= 70 (pulses coarse_start)
    %   - COARSE_EST -> LOAD    : coarse_valid
    %   - LOAD -> COSTAS_ACQ    : next str_valid
    %   - COSTAS_ACQ -> TRACK   : costas_lock || cnt >= 190 (pulses preamble_end)

    R   = T.rd;
    E   = T.enc.fsm;
    Lo  = T.lat.wrap_out; % 1 cycle
    Lpe = T.lat.derot + 1;

    % =====================================================================
    % 1. ACTIVE-LOW RESET (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.state    = uint8(E.WAIT_BURST);
        st.sym_cnt  = T.fi(0, 'cnt');
        st.cs       = false;
        st.pe_pipe  = false(1, Lpe);
        st.mode     = uint8(T.enc.mode.HOLD);
        st.slicer_q = true;
        st.cfo_hold = T.fi(0, 'cfo');
        st.fine     = T.fi(0, 'freq_w');
        st.ld       = false;
        st.ow_val             = false(1, Lo);
        st.ow_i               = T.fi(zeros(1, Lo), 'rot_out');
        st.ow_q               = T.fi(zeros(1, Lo), 'rot_out');
        st.idle_cnt           = 0;
        st.flush_cnt          = 0;
        st.flush_rst          = false;
        st.valid_during_flush = 0;

        out = wrap_drive_outputs(st, E);
        return;
    end

    st_old = st;
    cnt    = double(st_old.sym_cnt);
    if in.str_valid
        cnt = cnt + 1;
        st.sym_cnt(:) = cnt;
    end

    state     = double(st_old.state);
    new_state = state;
    new_cs    = false;
    new_pe    = false;
    st.flush_rst = false;

    valid_scheme = isfield(T, 'valid') && isfield(T.valid, 'enable') && logical(T.valid.enable);

    % =====================================================================
    % 2. STATE MACHINE TRANSITIONS
    % =====================================================================
    switch state
        case E.WAIT_BURST
            st.idle_cnt  = 0;
            st.flush_cnt = 0;
            if in.in_sample_valid
                new_state = E.ACQUIRE;
            end

        case E.ACQUIRE
            % STR acquisition: advance when STR declares lock or 70-symbol budget expires
            if in.str_valid
                if in.str_lock || (cnt >= T.preamble.N_A)
                    new_state = E.COARSE_EST;
                    new_cs    = true; % Start coarse CFO correlation
                end
            end

        case E.COARSE_EST
            % Wait for 32-symbol correlation + 16-stage CORDIC IP done
            if in.coarse_valid
                new_state = E.LOAD;
            end

        case E.LOAD
            % Wait for next STR symbol to align derotator start
            if in.str_valid
                new_state = E.COSTAS_ACQ;
            end

        case E.COSTAS_ACQ
            % Costas pull-in & Phase C: advance to TRACK when 190-symbol preamble completes
            if in.str_valid && (cnt >= T.N_preamble)
                new_state = E.TRACK;
                new_pe    = true; % Pulse preamble_end to force quadrant ambiguity evaluation
            end

        case E.TRACK
            % Steady-state payload tracking

        case E.FLUSH
            % Draining in-flight pipeline symbols for F clock cycles
            st.flush_cnt = st_old.flush_cnt + 1;
            if in.in_sample_valid
                st.valid_during_flush = st_old.valid_during_flush + 1;
            end
            if st_old.flush_cnt >= T.valid.flush_clocks
                new_state    = E.WAIT_BURST;
                st.flush_rst = true; % Single-cycle soft-reset pulse to re-arm all modules
                st.idle_cnt  = 0;
                st.flush_cnt = 0;
            end

        otherwise
            new_state = E.WAIT_BURST;
    end

    % Always-on Idle Watchdog (active during burst states)
    if valid_scheme && (state >= E.ACQUIRE) && (state <= E.TRACK)
        if ~in.in_sample_valid
            st.idle_cnt = st_old.idle_cnt + 1;
            if st.idle_cnt >= T.valid.idle_timeout
                new_state    = E.FLUSH;
                st.flush_cnt = 0;
            end
        else
            st.idle_cnt = 0;
        end
    end

    st.state = uint8(new_state);
    st.cs    = new_cs;

    % Determine Costas Loop Mode
    if new_state == E.COSTAS_ACQ
        st.mode = uint8(T.enc.mode.ACQ);
    elseif new_state == E.TRACK
        st.mode = uint8(T.enc.mode.TRACK);
    else
        st.mode = uint8(T.enc.mode.HOLD);
    end

    % Slicer QPSK Force Flag (true in all states except TRACK)
    st.slicer_q = (new_state ~= E.TRACK);
    st.pe_pipe  = [new_pe, st_old.pe_pipe(1 : end-1)];

    % Latch Coarse CFO
    if in.coarse_valid
        st.cfo_hold(:) = T.fi(in.coarse_word, 'cfo');
    end

    % Fine CFO: coarse_hold + costas_loop_integrator
    st.fine(:) = R(st_old.cfo_hold) + R(T.fi(in.costas_int, 'freq_w'));
    st.ld      = logical(in.str_lock) && logical(in.costas_lock);

    % 1-Cycle Output Register Stage
    st.ow_val  = [logical(in.derot_valid), st_old.ow_val(1 : end-1)];
    st.ow_i(:) = [R(T.fi(in.derot_i, 'rot_out')), R(st_old.ow_i(1 : end-1))];
    st.ow_q(:) = [R(T.fi(in.derot_q, 'rot_out')), R(st_old.ow_q(1 : end-1))];

    out = wrap_drive_outputs(st, E);
end

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================
function out = wrap_drive_outputs(st, E)
    out.out_sym_valid      = st.ow_val(end);
    out.out_sym_i          = st.ow_i(end);
    out.out_sym_q          = st.ow_q(end);
    out.coarse_cfo_est     = st.cfo_hold;
    out.fine_cfo_est       = st.fine;
    out.lock_detect        = st.ld;
    out.coarse_start       = st.cs;
    out.costas_mode        = st.mode;
    out.slicer_qpsk        = st.slicer_q;
    out.preamble_end       = st.pe_pipe(end);
    out.fsm_state          = st.state;
    out.flush_active       = (st.state == E.FLUSH);
    out.flush_rst          = st.flush_rst;
    out.valid_during_flush = st.valid_during_flush;
end
