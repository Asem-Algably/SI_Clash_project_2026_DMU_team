%% Isolated Component Test 03: Fine CFO & Costas Loop (CP4)
% Tests 16-QAM phase and residual frequency acquisition using data-aided
% preamble training followed by decision-directed slicing.

clear; clc; close all;
cur_file = mfilename('fullpath');
if ~isempty(cur_file)
    search_dir = fileparts(cur_file);
else
    search_dir = pwd;
end
for depth = 1:4
    if exist(fullfile(search_dir, 'setup_project.m'), 'file')
        addpath(search_dir);
        break;
    end
    search_dir = fileparts(search_dir);
end
setup_project(false);
cfg = get_default_config();
cfg.mod_type = 1; % 16-QAM

%% 1. Simulate Residual CFO + Phase Offset on 16-QAM Symbol Stream
% Train on 60 preamble symbols, then switch to decision-directed tracking.

N_train   = 60;
N_track   = 800;
train_sym = generate_preamble('period2', N_train);
pay_sym   = generate_payload(cfg.mod_type, N_track, 99);
all_syms  = [train_sym; pay_sym];

res_cfo   = 0.004;
phi_0     = 35 * (pi/180);
n         = (0:numel(all_syms)-1).';
rx_syms   = all_syms .* exp(1j * (2*pi*res_cfo*n + phi_0));
rx_syms   = rx_syms + sqrt(10^(-20/10)/2)*(randn(size(rx_syms)) + 1j*randn(size(rx_syms)));

costas_out = run_costas_subsystem(rx_syms, cfg, 0.0, train_sym);

figure('Color', 'w', 'Name', 'CP4: Isolated Costas Loop (16-QAM)');
subplot(1,2,1);
plot(real(costas_out.sym_derot(N_train+100:end)), imag(costas_out.sym_derot(N_train+100:end)), 'b.');
grid on; axis equal; xlim([-1.2 1.2]); ylim([-1.2 1.2]);
title('Derotated 16-QAM Constellation (After Lock)');
xlabel('In-Phase (I)'); ylabel('Quadrature (Q)');

subplot(1,2,2);
plot(costas_out.freq_log, 'b', 'LineWidth', 1.5); hold on;
yline(res_cfo, 'r--', 'True Residual CFO'); grid on;
xlabel('Symbol Index'); ylabel('NCO Frequency Word (f / R_{sym})');
title(sprintf('Costas Frequency Pull-In (Locked @ Symbol %.0f)', costas_out.lock_sym));
