function [fsm_next, costas_mode, preamble_end_pulse] = burst_fsm(fsm, in_valid, str_locked, N_AB, N_preamble)
    % Burst Controller State Machine (matches wrapper.md Section 4):
    % States: WAIT_BURST -> ACQUIRE -> COARSE_EST -> LOAD -> COSTAS_ACQ -> TRACK
    % Costas modes: HOLD (WaitBurst..Load), ACQ (CostasAcq), TRACK (Track)
    fsm_next           = fsm;
    preamble_end_pulse = false;

    if ~in_valid
        fsm_next.state       = 'WAIT_BURST';
        fsm_next.state_timer = 0;
        costas_mode          = 'HOLD';
        return;
    end

    switch fsm.state
        case 'WAIT_BURST'
            fsm_next.state       = 'ACQUIRE';
            fsm_next.state_timer = 1;
            costas_mode          = 'HOLD';

        case 'ACQUIRE'
            costas_mode = 'HOLD';
            fixed_start = 0;
            if isfield(fsm, 'fixed_start_sym')
                fixed_start = fsm.fixed_start_sym;
            end
            max_acq = max(N_AB - fsm.coarse_win_len - 4, 20);
            if fixed_start > 0
                go_coarse = (fsm.sym_cnt >= fixed_start);
            else
                go_coarse = (str_locked || fsm.sym_cnt >= max_acq);
            end
            if go_coarse
                fsm_next.state       = 'COARSE_EST';
                fsm_next.state_timer = 1;
            else
                fsm_next.state_timer = fsm.state_timer + 1;
            end

        case 'COARSE_EST'
            costas_mode = 'HOLD';
            if fsm.state_timer < fsm.coarse_win_len
                fsm_next.state_timer = fsm.state_timer + 1;
            else
                fsm_next.state       = 'LOAD';
                fsm_next.state_timer = 1;
            end

        case 'LOAD'
            costas_mode          = 'HOLD';
            fsm_next.state       = 'COSTAS_ACQ';
            fsm_next.state_timer = 1;

        case 'COSTAS_ACQ'
            costas_mode = 'ACQ';
            if fsm.sym_cnt >= N_preamble
                preamble_end_pulse   = true;
                fsm_next.state       = 'TRACK';
                fsm_next.state_timer = 1;
                costas_mode          = 'TRACK';
            else
                fsm_next.state_timer = fsm.state_timer + 1;
            end

        case 'TRACK'
            costas_mode          = 'TRACK';
            fsm_next.state_timer = fsm.state_timer + 1;

        otherwise
            fsm_next.state       = 'WAIT_BURST';
            fsm_next.state_timer = 0;
            costas_mode          = 'HOLD';
    end
end
