function [fsm_next, costas_mode] = burst_fsm(fsm, in_valid, str_locked, costas_settled, N_AB, N_preamble)
    % Hierarchical Burst Controller State Machine (Part B2 & Fix 6):
    % States: WAIT_BURST -> ACQUIRE -> COARSE_EST -> LOAD -> COSTAS_ACQ -> QUAD_CHECK -> TRACK
    % Parallel Costas modes: HOLD (through LOAD), ACQ (decision-directed), TRACK
    fsm_next = fsm;
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
            if fsm.sym_cnt >= (N_AB + 1) && costas_settled
                fsm_next.state       = 'QUAD_CHECK';
                fsm_next.state_timer = 1;
            elseif fsm.sym_cnt >= N_preamble
                fsm_next.state           = 'TRACK';
                fsm_next.state_timer     = 1;
                fsm_next.quad_unresolved = true;
                costas_mode              = 'TRACK';
            else
                fsm_next.state_timer = fsm.state_timer + 1;
            end

        case 'QUAD_CHECK'
            costas_mode = 'ACQ';
            if fsm.sym_cnt >= N_preamble
                fsm_next.state       = 'TRACK';
                fsm_next.state_timer = 1;
                costas_mode          = 'TRACK';
            else
                fsm_next.state_timer = fsm.state_timer + 1;
            end

        case 'TRACK'
            costas_mode          = 'TRACK';
            fsm_next.state_timer = fsm.state_timer + 1;
    end
end
