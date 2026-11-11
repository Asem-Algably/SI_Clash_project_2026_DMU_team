function R_D = conj_autocorr(rx_win, D, ref_preamble, data_aided)
    rx_win = rx_win(:);
    N = numel(rx_win);
    if N <= D
        error('Correlation window length (%d) must exceed lag D (%d).', N, D);
    end
    r_late  = rx_win(1+D : N);
    r_early = rx_win(1 : N-D);
    prod_r  = r_late .* conj(r_early);

    if nargin >= 4 && data_aided && ~isempty(ref_preamble) && numel(ref_preamble) >= N
        ref_preamble = ref_preamble(:);
        p_win  = ref_preamble(1:N);
        p_diff = p_win(1+D : N) .* conj(p_win(1 : N-D));
        prod_r = prod_r .* conj(p_diff);
    end
    R_D = sum(prod_r);
end
