# Si-CLASH Carrier & Timing Synchronization Unit — Unified Floating-Point & Cycle-Accurate Fixed-Point Golden Model

## 1. Overview & Clean Architecture
This repository unifies the **Symbol-Rate Floating-Point Golden Model** and the **Clock-Accurate, Interface-Accurate Fixed-Point Golden Model** (`CLOCK_ACCURATE_MODELING_STANDARD.md`) into a single cohesive codebase with **zero duplicate files**.

Switch execution modes at any time using a single field in `config/get_default_config.m`:
* **`cfg.exec_mode = 'fixed_cycle'` (Default):** Steps one hardware clock edge (`125 MHz`) per iteration using `w_prev = w` wire snapshots, exact RTL port structs (`s_axis_*`, `m_axis_*`), lumped hardware pipeline shift registers, and Fixed-Point Designer (`fi`) types.
* **`cfg.exec_mode = 'float_cycle'`:** Runs the exact same cycle-accurate RTL `step_*` state machines in double precision (`DataTypeOverride`) to isolate timing/pipeline bugs from quantization noise.
* **`cfg.exec_mode = 'float_symbol'`:** Runs the fast symbol-rate floating-point model for rapid Monte-Carlo sweeps.

---

## 2. Directory Structure
```text
si_clash_fxp_golden_model/
├── setup_project.m                       # One-click MATLAB path setup & Live Script (.mlx) compiler
├── config/
│   ├── get_default_config.m              # Master parameter struct (channel, loops, schedule, fxp widths & latencies)
│   ├── get_hw_types_and_cfg.m            # Builds Fixed-Point Designer numerictypes, fimaths, LUTs, and T.fi/T.rd helpers
│   ├── compute_loop_gains.m              # Computes (Kp, Ki) with closed-loop delay compensation
│   ├── decode_gain_ports.m               # Gain port wrapper
│   └── get_constellation_map.m           # 'peak' and 'rms' constellation definitions
├── tx_channel/
│   ├── generate_preamble.m               # 3-phase preamble with Phase C = [Q1, Q2, Q4, Q1]
│   ├── generate_payload.m                # QPSK and 16-QAM payload generator
│   ├── pulse_shape_rrc.m                 # Root-Raised Cosine TX/RX matched filter
│   └── apply_channel_impairments.m       # Fractional delay, CFO, phase offset, AWGN, RX RRC
├── rx_blocks/
│   ├── run_synchronizer_top.m            # Unified entry point (routes to cycle-accurate or symbol-rate model)
│   ├── run_cycle_accurate_top.m          # Master clock-edge loop (w_prev = w) & symbol-rate logger
│   ├── str/
│   │   ├── step_str.m                    # Cycle-accurate Fixed-Point STR module (str.md)
│   │   ├── run_str_subsystem.m           # Symbol-rate Float STR module
│   │   ├── farrow_interpolator.m         # Parabolic (Q4.12 internal, Q2.14 output) & Cubic Farrow
│   │   ├── modulo1_controller.m          # Two-region Modulo-1 controller with wrap-around protection
│   │   └── gardner_ted.m                 # Gardner TED
│   ├── coarse_cfo/
│   │   ├── step_coarse_cfo.m             # Cycle-accurate Fixed-Point Coarse CFO + 16-stage CORDIC (coarse_cfo.md)
│   │   ├── run_coarse_cfo_subsystem.m    # Symbol-rate Float Coarse CFO
│   │   ├── conj_autocorr.m               # Lag-4 autocorrelation
│   │   └── angle_solver.m                # atan2 / bisection angle solver
│   ├── costas/
│   │   ├── step_derotator.m              # Cycle-accurate Fixed-Point Derotator & 32-bit NCO (derotator.md)
│   │   ├── step_costas.m                 # Cycle-accurate Fixed-Point Costas Loop & 5-bit sign counters (costas.md)
│   │   ├── run_costas_subsystem.m        # Standalone Costas test wrapper
│   │   ├── derotator.m                   # Quarter-wave LUT derotator
│   │   ├── qam_slicer.m                  # QPSK / 16-QAM slicer
│   │   ├── costas_phase_detector.m       # Phase error detector
│   │   └── nco_32bit.m                   # NCO helper
│   └── control/
│       ├── step_wrapper_fsm.m            # Cycle-accurate Fixed-Point Wrapper Burst FSM (wrapper.md)
│       ├── burst_fsm.m                   # Symbol-rate Burst FSM
│       ├── dynamic_lock_detector.m       # EMA + hysteresis + leaky bucket lock detector
│       └── init_lock_state.m             # Lock detector initializer
├── utils_metrics/                        # Shared Scorer, Spec Report & Diagnostic Plots
└── experiments/                          # Acceptance Tests & Fixed-vs-Float Benchmark (test_fixed_vs_float.m)
```
