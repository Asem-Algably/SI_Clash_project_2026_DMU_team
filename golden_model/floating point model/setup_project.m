function setup_project(force_rebuild_mlx)
% Initializes MATLAB paths and compiles Live Scripts from live_scripts/src/*.m
% into live_scripts/*.mlx (without keeping duplicate .m files in live_scripts/).
    if nargin < 1
        force_rebuild_mlx = false;
    end
    root_dir = fileparts(mfilename('fullpath'));
    if isempty(root_dir)
        root_dir = pwd;
    end

    folders = {
        'config', ...
        'tx_channel', ...
        'rx_blocks', ...
        'rx_blocks/str', ...
        'rx_blocks/coarse_cfo', ...
        'rx_blocks/costas', ...
        'rx_blocks/control', ...
        'utils_metrics', ...
        'live_scripts', ...
        'experiments'
    };

    for i = 1:numel(folders)
        target_dir = fullfile(root_dir, folders{i});
        if ~exist(target_dir, 'dir')
            mkdir(target_dir);
        end
        addpath(target_dir);
    end
    addpath(root_dir);

    src_dir = fullfile(root_dir, 'live_scripts', 'src');
    out_dir = fullfile(root_dir, 'live_scripts');

    % Remove any duplicate .m files sitting directly in live_scripts/
    stray_m = dir(fullfile(out_dir, '*.m'));
    for s = 1:numel(stray_m)
        delete(fullfile(stray_m(s).folder, stray_m(s).name));
    end

    if exist(src_dir, 'dir')
        src_files = dir(fullfile(src_dir, '*.m'));
        for k = 1:numel(src_files)
            m_path = fullfile(src_files(k).folder, src_files(k).name);
            [~, base_name] = fileparts(m_path);
            mlx_path = fullfile(out_dir, [base_name, '.mlx']);
            if force_rebuild_mlx || ~exist(mlx_path, 'file')
                try
                    matlab.internal.liveeditor.openAndSave(m_path, mlx_path);
                catch
                    if exist('export', 'file')
                        export(m_path, mlx_path);
                    end
                end
            end
        end
    end

    disp('[SETUP] Synchronizer paths added and .mlx Live Scripts compiled in live_scripts/.');
end
