# Project: RX Synchronizer RTL Reorganization and Discrepancy Analysis

## Architecture
The RX Synchronizer is an all-digital burst receiver synchronization subsystem for carrier and timing recovery (operating at $F_{clk} = 125\text{ MHz}$, $Ns = 4\text{ sps}$, $R_{sym} = 31.25\text{ MSps}$).
It integrates:
1. **Top Integration & Control**: `sync_system_top` with `burst_ctrl`, `dft_mux`, `err_align`, and `reset_sync` (and alternative `top_wrapper` with `wrapper_fsm`). Controls 7-state burst sequencing, preamble phases (A1: 70 syms, A2: 40 syms, B: 30 syms, C: 50 syms = 190 total), 14-clock watchdog, and 16-clock flush.
2. **Symbol Timing Recovery (STR)**: `str_top` integrating `modulo_1_controller`, `parabolic_farrow_interpolator`, `gardner_ted_estimator`, `pI_loop`, and lock detection.
3. **Coarse Frequency Offset (CFO) Estimator**: `coarse_cfo_core` integrating lag-4 complex multiplier, 32-symbol correlation accumulator, and 16-iteration vectoring CORDIC atan2 solver.
4. **Derotator**: `derotator` integrating 32-bit wrapping NCO phase accumulator, 4096-entry quarter-wave sine LUT ROM, quadrant rotator, and pipelined complex multiplier.
5. **Costas Loop**: `costas_top` integrating decision-directed slicer (QPSK/16-QAM), cross-product phase error detector, PI loop filter with anti-windup, dual lock detectors, and 5-bit saturating sign counters for 90-degree quadrant ambiguity resolution.

## Code Layout
- `code/rtl/top/`: Top-level integration wrappers, burst control FSMs, DFT observation mux, error alignment.
- `code/rtl/str/`: Symbol timing recovery modules (interpolator, TED, NCO, PI loop).
- `code/rtl/coarse_cfo/`: Coarse frequency estimation modules (correlator, accumulator, CORDIC).
- `code/rtl/derotator/`: Carrier derotation modules (NCO, LUT, rotator, multiplier).
- `code/rtl/costas/`: Carrier phase tracking modules (slicer, phase detector, loop filter, lock detector, ambiguity resolver).
- `code/tb/`: Testbenches (`tb/top/`, `tb/str/`, `tb/coarse_cfo/`, `tb/derotator/`, `tb/costas/`) and test vectors (`code/tb/top/*.hex`).
- `code/scripts/questa/`: QuestaSim compilation and simulation macros (`.do` files).
- `model/fixed_point_model/`: MATLAB fixed-point golden model (`rx_blocks/`, `config/`, `test_vectors/`, `tx_channel/`, `utils_metrics/`, `experiments/`).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | File Organization & Layout Verification | Verify all 51 incoming files relocated, directories cleaned, duplicates audited, reset_sync differences documented | M1 | explorer_survey_1 |
| 2 | Top Integration & Wrapper Harmonization | Analyze duality between `sync_system_top` and `top_wrapper`, verify port matching and watchdog drain | M2 | explorer_survey_3 |
| 3 | Burst FSM & Preamble Schedule | Audit 190-symbol schedule: Phase A1 (70), A2 (40), B (30), C (50). Resolve `burst_ctrl.sv` 155-symbol truncation | M2 | spec_miner_survey_2, explorer_survey_3 |
| 4 | Derotator Input Gating | Analyze NCO phase accumulation during STR acquisition vs suppressed gating (`fsm >= LOAD`) | M2 | explorer_survey_3 |
| 5 | Farrow Parabolic Interpolator Math & Latency | Compare Horner MAC form vs direct polynomial evaluation, $\mu$ orientation, Q1.14 vs Q1.15, 4 vs 5 cycle latency | M2 | spec_miner_survey_2, explorer_survey_3 |
| 6 | Gardner Timing Error Detector | Compare TED error word lengths: 25-bit sQ3.21 in model vs 32-bit sQ3.29 in RTL | M2 | spec_miner_survey_2, explorer_survey_3 |
| 7 | STR PI Loop Filter & Anti-Windup | Compare 16-bit Q1.15 fixed gains (`KP=0x0200`, `KI=0x0020`) vs 24/26-bit high precision fractional gains | M2 | spec_miner_survey_2, explorer_survey_3 |
| 8 | STR Lock Detector & Leaky Bucket | Audit lock thresholds, EMA smoothing shift, enter/exit hysteresis | M2 | spec_miner_survey_2 |
| 9 | Coarse CFO Correlation & Priming | Audit 4-sample delay line priming, 28-product conjugate accumulation over 32 symbols | M2 | spec_miner_survey_2, explorer_survey_3 |
| 10 | Coarse CFO CORDIC Angle Solver Latency | Reconcile 16-stage CORDIC iterative FSM (18-20 cycles) vs model 16-cycle fixed latency | M2 | spec_miner_survey_2, explorer_survey_3 |
| 11 | Derotator NCO & Quarter-Wave Sine LUT | Verify 32-bit natural wrapping, 4096 midpoint quarter-wave table symmetry, complex multiplication | M2 | spec_miner_survey_2 |
| 12 | Costas Loop Slicer Modes | Verify forced QPSK during preamble and QPSK/16-QAM in tracking, modulation delay pipeline | M2 | spec_miner_survey_2, explorer_survey_3 |
| 13 | Costas Phase Detector & Feedback Latency | Reconcile 6-cycle RTL pipeline latency (3 detector + 3 filter) vs 5-cycle model parameter | M2 | spec_miner_survey_2, explorer_survey_3 |
| 14 | Costas PI Loop Filter & Gain Scaling | Verify anti-windup clamping to $\pm 0.1200$, frequency adjustment scaling, delay compensation | M2 | spec_miner_survey_2 |
| 15 | Costas Lock Detectors & Threshold Discrepancy | Audit threshold doubling (4096 / 5500 for QPSK) in `costas_top.sv` vs nominal values (2064 / 3277) | M2 | explorer_survey_3 |
| 16 | Quadrant Ambiguity Resolution | Audit 5-bit saturating sign counters $[-16, +15]$, Phase C timing, preamble_end pulse pipeline alignment | M2 | spec_miner_survey_2, explorer_survey_3 |
| 17 | Golden Model Config & Test Vector Exporter Bugs | Document stale `hw_parameters_exported.txt` and unquantized double truncation bug in `export_test_vectors.m` | M2 | spec_miner_survey_2 |
| 18 | Final Discrepancy Report & Stop Checkpoint | Compile comprehensive discrepancy catalog with RTL/Model locations and modification recommendations for user review | M3 | Dispatch |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | File Organization & Layout Verification | Verify relocation of all 51 incoming files from `code/latest code/top_module/` to repository locations, deletion of `code/latest code/`, and audit of repository hygiene | none | DONE |
| M2 | Comprehensive RTL vs Golden Model Discrepancy Analysis | Perform deep module-by-module line-by-line comparison between RTL and `model/fixed_point_model`, cataloging all functional, timing, latency, and format discrepancies | M1 | DONE |
| M3 | User Consultation Discrepancy Report & Alignment Execution | Compile all verified findings into an executive report for user review, align discrepancies (TED scaling, priming, latencies, thresholds), and verify 100% clean compilation | M2 | DONE |

## Interface Contracts
### `sync_system_top` ↔ Submodules
- `str_top`: Receives `in_sample_i/q` (sQ0.11), outputs `str_sym_i/q` (sQ1.14/sQ1.15) and `str_valid` strobe.
- `burst_ctrl`: Receives `str_valid`, tracks 190-symbol preamble budget, outputs `coarse_start_o`, `preamble_end_o`, `costas_mode_o`, `flush_active_o`.
- `coarse_cfo_core`: Triggered by `coarse_start`, accumulates 32 symbols, computes CORDIC atan2, outputs `cfo_est` (sQ-1.24) and `cfo_valid`.
- `derotator`: Receives `str_sym_i/q`, `coarse_cfo_est`, and Costas `freq_adj`, applies NCO rotation, outputs `derot_sym_i/q` (sQ1.14).
- `costas_top`: Receives `derot_sym_i/q`, slices decisions, computes phase error, updates loop filter, resolves quadrant ambiguity, outputs `fine_cfo_est` and `lock_detect`.
