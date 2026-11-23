function [payload_syms, const] = generate_payload(mod_type, N_payload, seed, norm_mode)
    % Part 0a: Reads constellation scale strictly from get_constellation_map(mod_type, norm_mode).
    if nargin >= 3 && ~isempty(seed)
        rng(seed);
    end
    if nargin < 3 || isempty(norm_mode)
        norm_mode = 'peak';
    end
    const = get_constellation_map(mod_type, norm_mode);
    idx   = randi([1, const.M], N_payload, 1);
    payload_syms = const.symbols(idx);
end
