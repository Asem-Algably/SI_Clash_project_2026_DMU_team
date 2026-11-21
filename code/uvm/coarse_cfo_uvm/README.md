# Verification Plan — Coarse CFO Estimator (`coarse_cfo_core`)

**Status legend:** `[DONE]` · `[PART]` · `[PLAN]`
**Environment:** `coarse_cfo_core_uvm/` · **Vectors:** `tb_coarse_vec.hex` (per-line: valid, I, Q, start, expected-valid, expected CFO) · **Report:** `coverage_rpt_coarse_cfo_core.txt`

---

## 1. DUT summary

Lag-4 autocorrelation estimator. Computes `R = Σ r[n]·conj(r[n−4])` over a 32-symbol window, then `angle(R) >> 2` through a CORDIC. Output is a signed 24-bit turn-per-symbol word (2^24 = one turn).

| Item | Detail |
|---|---|
| Parameters | `DataWidth = 16`, `Lag = 4`, `WinLen = 32`, `AccWidth = 40` |
| Inputs | `start_i` (level: window active), `s_axis_valid_i` strobe, 16-bit I/Q symbols, `force_cfo_en_i/force_cfo_i` |
| Outputs | `m_axis_valid_o` (one pulse), `m_axis_cfo_o` (held estimate) |
| Sub-blocks | `complex_mult`, `accumulator`, `cordic_angle` |
| DFT | `force_cfo_en_i` replaces the stored estimate with `force_cfo_i` |
| Golden value | `coarse_cfo_stored = 1089400` (about 0.065 turn/symbol), scoreboard tolerance ±5000 |

Note: the RTL comment says "Async reset", but the code uses a synchronous reset (`always_ff @(posedge clk_i)` with `if (!rst_ni)`). Verification follows the code; fix the comment.

---

## 2. Environment (as built)

| Component | Behavior |
|---|---|
| Sequences | `reset_seq`, `golden_seq` (`$readmemh` of `tb_coarse_vec.hex`), `directed_cfo_seq`, `coarse_cfo_main_seq` |
| `directed_cfo_seq` | Three tones at normalized CFO 0.005, −0.01, −0.25 (32 symbols each, 20 idle between), a constant-vector window, and a forced-CFO window (`0xABCDEF`) |
| Scoreboard | On each `o_valid` pulse, accepts `expected_cfo ± tolerance` (1089400 ± 5000); counts correct / wrong |
| Coverage | `g1`: `cp_valid` (2 bins), `cp_cfo` (zero, small ±, large ±; 5 bins) |
| SVA | One assertion: `m_axis_cfo_o` is not X when `m_axis_valid_o` |
| Interface | Includes `force_rst_low/high/release` tasks for reset-mid-window tests |

---

## 3. Feature list and traceability

| ID | Feature | Method | Status |
|---|---|---|---|
| CFO-01 | Estimate within tolerance of golden for the reference window | Golden sequence + scoreboard | [DONE] |
| CFO-02 | Exactly one `m_axis_valid_o` pulse per window | Count pulses vs windows | [PLAN] |
| CFO-03 | Estimate accuracy over a CFO sweep (tones at ±0.005, −0.01, −0.25 in directed seq) | Compare to ideal `angle/2π·2^24/…` computed in the TB | [PART] (stimulus present; scoreboard only checks the golden value) |
| CFO-04 | Sign and wrap behavior near ±0.5 turn/symbol ambiguity limit (lag 4 → ±1/8) | Tones near ±0.125 and beyond | [PLAN] |
| CFO-05 | Window length: result after exactly 32 symbols, ignore beyond `WinLen` | Windows of 31, 32, 40 symbols | [PART] (directed seq has 32 and 40) |
| CFO-06 | `start_i` low clears the symbol counter / restarts a window | Drop `start_i` mid-window | [PLAN] |
| CFO-07 | Valid gaps inside a window (strobe-driven accumulation) | Gapped symbol strobes | [PLAN] |
| CFO-08 | `force_cfo_en_i` overrides the estimate | Directed (`0xABCDEF`) + check of `m_axis_cfo_o` | [PART] (stimulus present, no explicit check) |
| CFO-09 | Reset clears counter and estimate | `force_rst_*` tasks mid-window | [PLAN] |
| CFO-10 | Input extremes (full-scale, zero, DC) — no accumulator overflow (40-bit) | Directed | [PLAN] |
| CFO-11 | CORDIC accuracy: error vs ideal `atan2` over the full angle range | Angle sweep through the sub-block or via tones | [PLAN] |
| CFO-12 | No X on valid output | SVA | [DONE] |
| CFO-13 | Latency from last symbol to `m_axis_valid_o` is constant | SVA/measure | [PLAN] |
| CFO-14 | Noise robustness (estimate spread vs SNR) | Noisy vectors | [PLAN] |

---

## 4. Test list

| Test | Stimulus | Checking | Status |
|---|---|---|---|
| Golden | reset → `golden_seq` | Scoreboard tolerance | [DONE] |
| Directed | `directed_cfo_seq` | Coverage, SVA (scoreboard compares to the *golden* value, so tone results are not validated) | [PART] |
| `t_cfo_sweep` | Tones from −0.12 to +0.12 in steps | Estimate vs ideal within quantization bound | [PLAN] |
| `t_restart` | Restart `start_i` mid-window | Counter cleared, one pulse for the new window | [PLAN] |
| `t_force` | Force several values | `m_axis_cfo_o == force_cfo_i` | [PLAN] |
| `t_reset_mid` | Reset during accumulation | No output after reset, clean next window | [PLAN] |

---

## 5. Checkers

- **Existing:** tolerance compare to 1089400 on each valid pulse; SVA no-X.
- **Needed:** (a) pulse count per window; (b) an SV reference computing the ideal estimate for any stimulus; (c) latency check; (d) assertion that `m_axis_valid_o` is a single-cycle pulse; (e) assertion that `m_axis_cfo_o` is stable between pulses unless forced.

Proposed SVA:

```
a_valid_onecycle : m_axis_valid_o |=> !m_axis_valid_o
a_hold           : !m_axis_valid_o && !force_cfo_en_i |=> $stable(m_axis_cfo_o)
a_force          : force_cfo_en_i |=> (m_axis_cfo_o == $past(force_cfo_i))   // after the registered update; confirm timing in RTL
```

---

## 6. Coverage plan

### 6.1 Functional

Existing `g1` has 7 bins and is **100 %** in the supplied report. Add:

| Item | Why |
|---|---|
| `cp_start` and `cp_s_valid` with transitions | Window control |
| `cp_force_en` | Override |
| `cp_window_len` bins (<32, 32, >32) | Window boundaries |
| `cp_input_mag` (zero, small, full-scale) | Overflow/precision |
| `cp_cfo` fine bins around ±1/8 turn | Ambiguity region |
| Cross `cp_force_en × cp_valid` | Forced result on a pulse |

### 6.2 Code coverage (supplied report)

| Metric | Reported | Target |
|---|---|---|
| Statement | 100 % in `complex_mult`/core units; 66.66 % in one unit (interface) | ≥ 95 % |
| Branch | 100 % in listed units | ≥ 90 % |
| Condition | 85.71 % (one term missing) | ≥ 85 %, justify the miss |
| Toggle | 86.62 % … 100 % by instance | ≥ 80 % |
| Assertions | 1/1 pass | Add the proposed three |
| Total by instance (filtered) | 84.84 % | ≥ 90 % |

---

## 7. Gaps and recommended actions

1. The scoreboard accepts only one expected value; the directed tones (0.005, −0.01, −0.25) are **not validated**. Add an SV reference estimate so every tone is checked.
2. The −0.25 turn/symbol tone is beyond the lag-4 unambiguous range (±1/8): expected behavior is an alias. Document the expected alias value instead of treating it as an error.
3. No check that a pulse occurs at all: if the DUT never pulses, the test still reports 0 wrong. Add `correct_count > 0` and an expected pulse count.
4. Add pulse-count, hold and latency assertions (section 5).
5. Fix the "Async reset" comment in the RTL.

## 8. Alignment with the top-wrapper UVM

- At the wrapper, `start_i` is the **level** `coarse_start` from `burst_ctrl`; the sub-UVM drives it per item. The wrapper window is the interval between Acquire exit and `coarse_valid`.
- Top-level check already implemented: `coarse_cfo_est` at CostasAcq entry within ±5000 of 1089400 (same tolerance).
- **Planned:** stage check on `coarse_valid` pulse count (exactly one per burst) and on `coarse_cfo_est` being held until the soft reset.
- The wrapper feeds this block with STR symbols (16-bit), not synthetic tones; the sub-UVM remains the place for CFO sweeps.

## 9. Exit criteria

Golden PASS; tone sweep validated against the SV reference; CFO-01…14 closed or justified; functional coverage 100 % with additions; statement/branch/condition targets met; all assertions pass.
