function state = dynamic_lock_detector(err_val, state, ema_shift, thr_enter, thr_exit, confirm_cnt, sym_idx)
    % Lock detector (matches the repo docs):
    %   1. |e|                      (negate if negative, no squaring)
    %   2. m <- m + (|e| - m)*2^-K  (moving average, shift K = ema_shift, 4 in the docs)
    %   3. two thresholds           (hysteresis: thr_enter < thr_exit)
    %        not good -> good when m < thr_enter ;  good -> not good when m > thr_exit
    %   4. leaky bucket             (+1 per good symbol, -2 per bad symbol, 0..confirm_cnt)
    %        locked is set when the bucket is full and cleared when it is empty.
    % err_val must already be normalised (by K_ted or by the constellation power).
    a = abs(err_val);
    state.m = state.m + (a - state.m) * 2^(-ema_shift);

    if state.good
        if state.m > thr_exit
            state.good = false;
        end
    else
        if state.m < thr_enter
            state.good = true;
        end
    end

    if state.good
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
