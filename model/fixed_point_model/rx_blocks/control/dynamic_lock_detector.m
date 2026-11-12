function state = dynamic_lock_detector(err_val, state, ema_shift, thr_enter, thr_exit, confirm_cnt, sym_idx)
    % DYNAMIC_LOCK_DETECTOR  Leaky-bucket hysteresis lock detector (str.md / costas.md).
    %
    % Operating Principle:
    %   1. Absolute Error Metric: |e| (negate if negative, avoiding hardware multipliers).
    %   2. Exponential Moving Average: m <- m + (|e| - m) * 2^-K (shift K = ema_shift = 4).
    %   3. Hysteresis Thresholding:
    %      - While unlocked (good=false): transitions to good when m < thr_enter.
    %      - While locked (good=true)   : transitions to bad when m > thr_exit.
    %   4. Asymmetric Leaky Bucket Counter:
    %      - +1 per good symbol, -2 per bad symbol (bounded between 0 and confirm_cnt).
    %      - Lock declared when bucket reaches confirm_cnt.
    %      - Lock revoked when bucket drops to 0.

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
