# Si-CLASH Carrier & Timing Synchronization Unit — Clean Architecture Fixed-Point Golden Model

## 1. Overview & Clean Single-File Modular Architecture
This repository implements the bit-exact, cycle-accurate **Fixed-Point Golden Model** for the Si-CLASH burst receiver synchronizer.

### Core Architecture Principles:
1. **Single File Per Submodule:**
   Each submodule in `rx_blocks/` is self-contained in exactly one `.m` file. Submodule helpers (Farrow Horner MAC, Gardner TED, loop filters, CORDIC IP, slicers, NCO, LUT, lock detectors) are inlined as private local functions.
2. **Pure Fixed-Point Datapath:**
   All wire buses and registers utilize Fixed-Point Designer (`fi`) objects with sized MSB guard bits. All arithmetic wraps via 2's complement except for the saturating PI loop filters with conditional anti-windup.
3. **Strict External Scaling:**
   The synchronizer internals do not perform arbitrary normalization. Scaling happens strictly at the boundaries:
   - Front-end ADC clips continuous signal to $[-2, 2 - 2^{-11}]$ and scales by $0.5$ into signed 12-bit Q1.11 `fi` in $[-1, 1 - 2^{-12}]$.
   - Metric scorer scales the output back by $\times 2$ to restore original amplitude.
4. **Single Hardcoded Operating Mode:**
   Hardcoded peak constellation normalization (QPSK $\pm 1$; 16-QAM $\pm 1/3, \pm 1$), 3-tap parabolic Farrow interpolator, and delay-compensated Costas loop.
5. **Exact 190-Symbol Preamble:**
   - Phase A1 (STR Acquire): 70 symbols, alternating diagonal Q4/Q2
   - Phase A2 (Coarse CFO): 40 symbols, alternating diagonal Q4/Q2 (WinLen = 32, Lag = 4)
   - Phase B (Costas Pull-in): 30 symbols, alternating diagonal Q4/Q2
   - Phase C (Quadrant Resolution): 50 symbols, repeated sequence $[Q1, Q2, Q1, Q4]$
6. **Slicer Modulation Pipelining:**
   Only the Costas slicer is aware of constellation modulation (`mod_type`). `mod_type` and valid strobes are pipelined to arrive synchronous with symbol data.
7. **Excess EVM Metric:**
   Evaluated strictly on payload symbols post-lock (preamble excluded):
   $$\text{EVM}_{\text{excess}} = \sqrt{\max(\text{EVM}_{\text{total}}^2 - \text{EVM}_{\text{floor}}^2, 0)}$$

---

## 2. Directory Structure
```text
model/fixed_point_model/
├── run_sim.m                             # Top-level executable simulation script
├── setup_project.m                       # Environment & MATLAB search path initialization
├── README.md                             # Architectural specification & documentation
├── config/
│   ├── get_hw_config.m                   # Master unified hardware configuration & constants
│   └── hw_parameters_exported.txt        # Register bit-widths & formats for RTL implementation
├── tx_channel/
│   └── generate_frame.m                  # Frame generator (190 preamble + payload, impairments, clipping, /2 ADC scaling)
├── rx_blocks/
│   ├── step_str.m                        # Single-file Symbol Timing Recovery (Modulo-1, Farrow, Gardner TED, PI, Lock)
│   ├── step_coarse_cfo.m                 # Single-file Coarse CFO (Lag-4 delay, 32-sum accumulator, 16-stage CORDIC IP)
│   ├── step_derotator.m                  # Single-file Derotator (32-bit NCO, 4096-entry sine LUT, quadrant pre-rotation)
│   ├── step_costas.m                     # Single-file Costas Loop (Slicer, Phase Detector, Saturating PI, Quadrant Resolver)
│   ├── step_wrapper_fsm.m                # Single-file Top Wrapper Burst FSM (6 states: WAIT, ACQ, CFO, LOAD, COSTAS, TRACK)
│   └── run_cycle_accurate_top.m          # Master clock-edge simulation harness with wire snapshots
└── utils_metrics/
    ├── compute_evm_and_metrics.m         # Fixed-point metric scorer (*2 scale restoration, Excess EVM, SER, Lock symbols)
    └── plot_sync_diagnostics.m           # 4-panel diagnostic visualization
```

---

## 3. Running the Simulation
To execute the complete fixed-point simulation from MATLAB:
```matlab
cd('model/fixed_point_model');
run_sim;
```

### Verified Performance Benchmarks:
| Metric | Specification Target | Verified Result | Status |
| :--- | :--- | :--- | :--- |
| **Excess EVM** | $< 10.0\%$ | **$7.39\%$** | **PASS** |
| **Total EVM (RMS)** | $< 10.0\%$ | **$9.71\%$** | **PASS** |
| **Symbol Error Rate (SER)** | $= 0.0000$ | **$0.0000$** | **PASS** |
| **STR Lock Symbol** | $\le 70$ symbols | **Symbol $53$** | **PASS** |
| **Coarse CFO Accuracy** | $|\Delta f| < 0.0005$ | **$\Delta f = 0.00003$** | **PASS** |
| **Costas Lock Symbol** | $\le 190$ symbols | **Symbol $190$** | **PASS** |
| **Quadrant Ambiguity** | Resolved ($k \in \{0,1,2,3\}$) | **Resolved ($k = 1$)** | **PASS** |
