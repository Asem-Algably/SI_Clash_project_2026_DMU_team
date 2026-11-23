function state = dynamic_lock_detector(err_val, state, alpha, var_thresh, confirm_cnt, sym_idx)
    state.ema_var = (1 - alpha) * state.ema_var + alpha * (err_val^2);
    if state.ema_var < var_thresh && sym_idx >= 15
        state.bucket = min(state.bucket + 1, confirm_cnt);
    else
        state.bucket = max(state.bucket - 2, 0);
    end
    if state.bucket >= confirm_cnt
        if ~state.locked && isnan(state.lock_sym)
            state.lock_sym = sym_idx;
        end
        state.locked = true;
    elseif state.bucket == 0
        state.locked = false;
    end
end
