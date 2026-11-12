function state = init_lock_state(m0)
    % INIT_LOCK_STATE  Initializes lock detector internal filter and bucket registers.
    % Starts the exponential moving average high (m = m0) so lock must be actively earned.

    state = struct('m', m0, 'good', false, 'bucket', 0, 'locked', false, 'lock_sym', NaN);
end
