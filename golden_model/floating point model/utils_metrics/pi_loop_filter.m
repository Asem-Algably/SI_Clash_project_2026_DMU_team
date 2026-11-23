function [v_out, int_next, sat_flag] = pi_loop_filter(e_in, int_cur, Kp, Ki, max_out)
    % Part 4a & 4b: Proportional-Integral (PI) loop filter with hardware safety
    % saturation limit (max_out) and conditional anti-windup.
    if nargin < 5 || isempty(max_out) || ~isfinite(max_out)
        int_next = int_cur + Ki * e_in;
        v_out    = Kp * e_in + int_next;
        sat_flag = false;
        return;
    end

    int_cand = min(max(int_cur + Ki * e_in, -max_out), max_out);
    v_raw    = Kp * e_in + int_cand;

    if abs(v_raw) > max_out
        sat_flag = true;
        v_out    = min(max(v_raw, -max_out), max_out);
        if (v_raw > max_out && e_in > 0) || (v_raw < -max_out && e_in < 0)
            int_next = int_cur;
        else
            int_next = int_cand;
        end
    else
        sat_flag = false;
        v_out    = v_raw;
        int_next = int_cand;
    end
end
