function [v_out, int_next, sat_flag] = pi_loop_filter(e_in, int_cur, Kp, Ki, max_out)
    % PI_LOOP_FILTER  Proportional-Integral (PI) filter with clamping anti-windup.
    %
    % Mathematical Model:
    %   1. Integral Accumulator:
    %      int_cand = clamp(int_cur + Ki * e_in, -max_out, +max_out)
    %   2. Proportional-plus-Integral Sum:
    %      v_raw = Kp * e_in + int_cand
    %   3. Saturation & Anti-Windup Clamping:
    %      If v_raw exceeds +-max_out, the output is clamped to +-max_out.
    %      If error drives the filter further into saturation, the integrator
    %      state freezes (int_next = int_cur) to prevent integrator windup.
    %
    % Inputs:
    %   e_in     - Error signal input (TED error or Costas phase error)
    %   int_cur  - Current integrator register state
    %   Kp       - Proportional filter coefficient
    %   Ki       - Integral filter coefficient
    %   max_out  - Symmetrical saturation limit (+-max_v_pi)
    %
    % Outputs:
    %   v_out    - Filter control output clamped to [-max_out, +max_out]
    %   int_next - Next-state integrator accumulator value
    %   sat_flag - Boolean indicator flagging saturation events

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
