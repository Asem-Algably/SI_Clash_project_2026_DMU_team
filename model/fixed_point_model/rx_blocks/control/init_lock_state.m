function state = init_lock_state(m0)
    % Start the moving average high (bad), never at the threshold, so lock must be earned.
    state = struct('m', m0, 'good', false, 'bucket', 0, 'locked', false, 'lock_sym', NaN);
end
