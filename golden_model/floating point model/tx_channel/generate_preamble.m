function preamble_syms = generate_preamble(preamble_type, N_preamble, cfg_pre)
    % Part 0a & B1: Reads constellation scale strictly from get_constellation_map(0, norm_mode).
    % Quadrant convention: Q1=(I>=0,Q>=0), Q2=(I<0,Q>=0), Q3=(I<0,Q<0), Q4=(I>=0,Q<0).
    norm_mode = 'peak';
    if nargin >= 3 && isstruct(cfg_pre) && isfield(cfg_pre, 'norm_mode')
        norm_mode = cfg_pre.norm_mode;
    elseif nargin >= 3 && (ischar(cfg_pre) || isstring(cfg_pre))
        norm_mode = char(cfg_pre);
    end
    c_qpsk = get_constellation_map(0, norm_mode);
    d_qpsk = c_qpsk.d;

    if nargin < 1 || isempty(preamble_type)
        preamble_type = 'q4q2_q1';
    end
    if nargin < 2 || isempty(N_preamble)
        N_preamble = 316;
    end

    switch lower(preamble_type)
        case 'q4q2_q1'
            N_A = 208;
            N_B = 60;
            N_C = 48;
            if nargin >= 3 && isstruct(cfg_pre)
                if isfield(cfg_pre, 'preamble')
                    N_A = cfg_pre.preamble.N_A;
                    N_B = cfg_pre.preamble.N_B;
                    N_C = cfg_pre.preamble.N_C;
                elseif isfield(cfg_pre, 'N_A')
                    N_A = cfg_pre.N_A;
                    N_B = cfg_pre.N_B;
                    N_C = cfg_pre.N_C;
                end
            end

            n_A   = (0:N_A-1).';
            seq_A = d_qpsk * (1 - 1j) * ((-1).^n_A);

            n_B   = (0:N_B-1).';
            seq_B = d_qpsk * (1 - 1j) * ((-1).^n_B);

            blk_C = [d_qpsk*(-1 + 1j); d_qpsk*(1 - 1j); d_qpsk*(1 + 1j); d_qpsk*(1 - 1j)];
            reps  = ceil(N_C / 4);
            seq_C = repmat(blk_C, reps, 1);
            seq_C = seq_C(1:N_C);

            full_seq = [seq_A; seq_B; seq_C];
            if N_preamble <= numel(full_seq)
                preamble_syms = full_seq(1:N_preamble);
            else
                n_ext = (0 : (N_preamble - numel(full_seq) - 1)).';
                ext   = d_qpsk * (1 - 1j) * ((-1).^n_ext);
                preamble_syms = [full_seq; ext];
            end

        case 'period2'
            alt = (-1).^(0:N_preamble-1).';
            preamble_syms = d_qpsk * (1 + 1j) * alt;

        case 'zadoff_chu'
            u = 1;
            n = (0:N_preamble-1).';
            preamble_syms = c_qpsk.rms_power * exp(-1j * pi * u * n .* (n + 1) / N_preamble);

        case 'barker'
            b13 = [1 1 1 1 1 -1 -1 1 1 -1 1 -1 1].';
            rep = repmat(b13, ceil(N_preamble/13), 1);
            s   = rep(1:N_preamble);
            preamble_syms = d_qpsk * (s + 1j * s);

        case 'pn'
            rng_state = rng;
            rng(101);
            bits_I = 2*randi([0 1], N_preamble, 1) - 1;
            bits_Q = 2*randi([0 1], N_preamble, 1) - 1;
            rng(rng_state);
            preamble_syms = d_qpsk * (bits_I + 1j * bits_Q);

        otherwise
            error('Unknown preamble_type: %s', preamble_type);
    end
end
