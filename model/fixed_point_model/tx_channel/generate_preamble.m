function preamble = generate_preamble(preamble_type, N_preamble, cfg)
    % GENERATE_PREAMBLE  Generates the 3-phase synchronization preamble.
    %
    % Structure ('q4q2_q1'):
    %   - Phase A (N_A symbols): Alternating Q4 (+d - j*d) and Q2 (-d + j*d)
    %     for timing acquisition and coarse CFO estimation (period-2 pattern).
    %   - Phase B (N_B symbols): Same alternating pattern for Costas frequency pull-in.
    %   - Phase C (N_C symbols): Repeats [Q1, Q2, Q4, Q1] sequence (Q3 is omitted).
    %     Both I and Q sign counters receive +2 net drift every 4 symbols, allowing
    %     unambiguous 90-degree quadrant ambiguity resolution.

    norm_mode = 'peak';
    if isstruct(cfg) && isfield(cfg, 'norm_mode')
        norm_mode = cfg.norm_mode;
    end
    c_qpsk = get_constellation_map(0, norm_mode);
    d      = c_qpsk.d;

    Q1 =  d + 1j * d;
    Q2 = -d + 1j * d;
    Q4 =  d - 1j * d;

    switch lower(strtrim(char(preamble_type)))
        case 'q4q2_q1'
            N_A = 84; N_B = 40; N_C = 40;
            if isstruct(cfg) && isfield(cfg, 'preamble')
                N_A = cfg.preamble.N_A;
                N_B = cfg.preamble.N_B;
                N_C = cfg.preamble.N_C;
            elseif exist('N_preamble', 'var')
                N_C = min(20, floor(N_preamble * 0.2));
                N_B = min(60, floor(N_preamble * 0.3));
                N_A = max(N_preamble - N_B - N_C, 0);
            end
            N_AB   = N_A + N_B;
            idx_ab = (0 : N_AB - 1).';
            % Alternating Q4 (even n) and Q2 (odd n): d*(1 - j)*(-1)^n
            seg_ab = d * (1 - 1j) .* ((-1) .^ idx_ab);

            % Phase C: repeat [Q1, Q2, Q4, Q1]
            pat_c = [Q1; Q2; Q4; Q1];
            reps  = ceil(N_C / 4);
            seg_c = repmat(pat_c, reps, 1);
            seg_c = seg_c(1:N_C);

            preamble = [seg_ab; seg_c];

        otherwise
            idx = (0 : N_preamble - 1).';
            preamble = d * (1 - 1j) .* ((-1) .^ idx);
    end
end
