function [payload_syms, const] = generate_payload(mod_type, N_payload, seed, norm_mode)
    % GENERATE_PAYLOAD  Synthesize random payload symbols from constellation map.
    %
    % Inputs:
    %   mod_type  - Modulation format (0 = QPSK, 1 = 16-QAM)
    %   N_payload - Number of payload symbols to generate (>= 1000 for CP6)
    %   seed      - (Optional) Random number generator seed for reproducibility
    %   norm_mode - Constellation normalization mode ('peak' or 'rms')
    %
    % Outputs:
    %   payload_syms - Generated complex symbol sequence
    %   const        - Active constellation mapping struct

    if exist('seed', 'var') ~= 0
        rng(seed);
    end
    if exist('norm_mode', 'var') == 0
        norm_mode = 'peak';
    end
    const = get_constellation_map(mod_type, norm_mode);
    idx   = randi([1, const.M], N_payload, 1);
    payload_syms = const.symbols(idx);
end
