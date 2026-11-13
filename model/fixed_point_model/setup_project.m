function setup_project(force_rebuild_mlx)
    % SETUP_PROJECT  Initialize project workspace paths and build Live Scripts.
    %
    % Operations:
    %   1. Recursively adds all model directories to the MATLAB search path:
    %      - config: loop filters, fixed-point widths, and hardware reports
    %      - tx_channel: transmitter, RRC shaping, AWGN, and channel impairments
    %      - rx_blocks: cycle-accurate RTL behavioral models (STR, CFO, Costas, Top)
    %      - utils_metrics: diagnostic EVM, lock metrics, and reporting
    %      - live_scripts, experiments: test runners and interactive notebooks
    %   2. Cleans up stray script copies and compiles live_scripts/src/*.m into .mlx
    %
    % Inputs:
    %   force_rebuild_mlx - (Optional) Boolean flag to force recompilation of .mlx files

    if exist('force_rebuild_mlx', 'var') == 0
        force_rebuild_mlx = false;
    end
    root_dir = fileparts(mfilename('fullpath'));

    % Ensure MinGW-w64 compiler path is registered for MEX / fiaccel acceleration
    if isempty(getenv('MW_MINGW64_LOC')) && exist('D:\w64devkit', 'dir')
        setenv('MW_MINGW64_LOC', 'D:\w64devkit');
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
