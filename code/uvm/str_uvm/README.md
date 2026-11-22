# Verification Plan — Symbol Timing Recovery (`str_top`)

**Status legend:** `[DONE]` implemented · `[PART]` partial · `[PLAN]` planned
**Environment:** `str_top_uvm/` · **Vectors:** `tb_str_vec.hex` · **Coverage report supplied:** `coverage_rpt_str_top.txt`

---

## 1. DUT summary

Structural top of the timing recovery loop: two parabolic Farrow interpolators (I/Q), a strobe alignment pipeline, a Gardner TED (sQ3.21), a PI loop filter, a modulo-1 NCO controller and a lock detector. Output symbols are sQ1.15. Reset is synchronous, active-low.

| Item | Detail |
|---|---|
| Clock enable | `ce_str = s_axis_valid_i \| flush_active_i` — the STR freezes when `ce_str = 0` |
| Inputs | 12-bit I/Q samples (4 per symbol), `loop_gain_i`, `flush_active_i`, `force_w_en_i/force_w_i` |
| Outputs | `m_axis_valid_o`, 16-bit I/Q symbols, `lock_o`, `ted_err_valid_o/ted_err_o`, `mu_o` (10 b), `w_o` (16 b) |
| Lock detector | EMA shift 4, enter 0x0000C6FA, exit 0x0001F172, confirm count 20 |
| Interpolation | Farrow, `MU_WIDTH = 10`, latency documented in RTL |

Sub-blocks: `parabolic_farrow_interpolator`, `gardner_ted_estimator`, `pI_loop`, `modulo_1_controller`, `lock_detector`.

---

## 2. Environment (as built)

| Component | Behavior |
|---|---|
| Sequences | `reset_seq` (5 reset + 2 idle clocks), `golden_seq` (replays `tb_str_vec.hex`, 18 hex digits: valid, I, Q, flush, exp_valid, exp_I, exp_Q, exp_lock), `str_main_seq` (QPSK smoke, 2000 samples) |
| Driver | Drives at negedge; forwards items with `exp_valid` to the scoreboard |
| Monitor | Samples all outputs every negedge |
| Scoreboard | Order-based, bit-exact I/Q compare per output strobe; `lock_o` compare informational (`check_lock = 0`) |
| Coverage | `g1`: `cp_out_valid`, `cp_lock`, `cp_ted_valid`, `cp_mu` (4 quartiles), `cx_valid_lock` |
| SVA | ~30 assertions on the internals (see section 5) |
| Test | `+SEQ=main` selects the directed smoke test with checking disabled |

---

## 3. Feature list and traceability

| ID | Feature | Method | Status |
|---|---|---|---|
| STR-01 | Reset values (outputs and counters) | SVA `a_reset_outputs` | [DONE] |
| STR-02 | Output symbols bit-exact vs golden | Scoreboard | [DONE] |
| STR-03 | No missing / extra output strobes | `leftover`, `extra_count` | [DONE] |
| STR-04 | Timing loop converges and locks (`lock_o` rises near symbol 54) | Golden vectors + `exp_lock` (informational) | [PART] |
| STR-05 | Clock-enable behavior: freeze when `ce_str = 0`, outputs held, valid drops | SVA `a_ce_definition`, `a_freeze_outputs`, `a_valid_drops_without_ce` | [DONE] |
| STR-06 | Strobe protocol: mid/current strobes exclusive, spacing, alternation, delay | SVA `a_strobe_*`, `a_curr_strobe_delay`, `a_mid_strobe_delay`, `a_alt_*`, `a_*_spacing` | [DONE] |
| STR-07 | `m_axis_valid_o` equals delayed current strobe | SVA `a_valid_is_curr_strobe_d` | [DONE] |
| STR-08 | `mu` changes only on strobe | SVA `a_mu_changes_on_strobe` | [DONE] |
| STR-09 | PI output and `w` stay in range | SVA `a_pi_range`, `a_w_range` | [DONE] |
| STR-10 | `force_w` override reaches the NCO | SVA `a_w_force_mux`; directed test | [PART] |
| STR-11 | Sample capture/hold of current, mid, previous points | SVA `a_cur_capture/hold`, `a_mid_capture/hold` | [DONE] |
| STR-12 | TED valid latency, value and sign extension | SVA `a_ted_valid_latency`, `a_ted_value`, `a_ted_sign_ext` | [DONE] |
| STR-13 | No X on control/data inputs, outputs, lock | SVA `a_inputs_*_known`, `a_outputs_known`, `a_lock_known` | [DONE] |
| STR-14 | Flush: `flush_active_i` keeps the STR running with repeated pad samples and drains the pipeline | Golden tail (`flush` column) | [PART] |
| STR-15 | Timing offset tolerance (fractional offsets across 0…1 sample) | New vectors | [PLAN] |
| STR-16 | Loop lock/unlock hysteresis (enter/exit thresholds, confirm count 20) | Vectors with degraded timing; lock drop and re-lock | [PLAN] |
| STR-17 | Noise robustness (TED jitter, lock stability) | SNR sweep vectors | [PLAN] |
| STR-18 | `loop_gain_i` effect | Confirm used/unused; sweep if used | [PLAN] |
| STR-19 | Valid gaps inside a burst (freeze/resume, no state corruption) | Directed gap test | [PLAN] |
| STR-20 | Input extremes (±2047), constant input, zero input | Directed test | [PLAN] |

---

## 4. Test list

| Test | Stimulus | Checking | Status |
|---|---|---|---|
| `str_top_test` default | reset → golden vectors → 20-clk drain | Scoreboard + SVA | [DONE] |
| `+SEQ=main` | QPSK smoke, 2000 samples + idle | SVA + coverage | [DONE] |
| `t_force_w` | Assert `force_w_en` with several values | `w_o` equals forced value; NCO step follows | [PLAN] |
| `t_gap` | Valid low for 1…N cycles mid-burst | Outputs freeze, no extras, resume exact | [PLAN] |
| `t_extremes` | Saturated / zero / DC input | No X, no overflow wrap, loop stays bounded | [PLAN] |
| `t_timing_offset` / `t_snr` | New vectors | Golden compare + lock behavior | [PLAN] |
| `t_lock_drop` | Lock, then corrupt timing, then recover | Lock deasserts/reasserts per thresholds | [PLAN] |

---

## 5. Checkers

- **Scoreboard:** bit-exact symbol compare in order, extras, leftovers, lock-difference count; PASS requires zero mismatches/extras/leftovers and at least one match.
- **SVA (in `sva.sv`, bound inside `str_top`):** reset, X-freedom (inputs, outputs, lock), clock-enable definition and freeze, strobe exclusivity/spacing/delays/alternation, valid-to-strobe relationship, `mu` update rule, PI/`w` ranges, force mux, sample capture/hold, TED latency/value/sign-extension, cover of current strobe.

---

## 6. Coverage plan

### 6.1 Functional (existing `g1`: 14 bins, **100 % in the supplied report**)

Add the following, because the current group only checks that signals toggled:

| Proposed item | Why |
|---|---|
| `cp_flush` (input) and cross with `cp_out_valid` | Flush behavior |
| `cp_force_w` | Override coverage |
| `cp_valid_gap` (gap length bins: 0, 1, 2–13, ≥14) | Freeze behavior |
| `cp_lock` transitions (0→1, 1→0) | Lock hysteresis |
| `cp_w` range bins | Loop operating range |
| `cp_ted_sign` | Positive/negative timing error |
| `cp_mu` cross with `cp_lock` | Fractional-delay coverage per lock state |

### 6.2 Code coverage (supplied report)

| Metric | Reported | Target |
|---|---|---|
| Statement | 100 % (44/44 in the listed unit) | ≥ 95 % |
| Branch | 100 % (14/14 in the listed unit) | ≥ 90 % |
| Toggle | 81.5 % … 98.25 % by instance | ≥ 80 %, waivers for constant bits |
| Total by instance (filtered) | 72.15 % | Track after additions |

---

## 7. Gaps and recommended actions

1. Lock is informational only; add a **lock-symbol-index check** against `str_lock_sym = 54` (± tolerance).
2. Only one golden scenario; STR-15/16/17 need extra vectors.
3. Functional coverage is 100 % but shallow (signal toggles). Extend as in 6.1.
4. Confirm what `loop_gain_i` does in the RTL; if unused, add an SVA that proves it has no effect.
5. `golden_seq` skips malformed lines silently; add a count check that the number of parsed lines equals the file's line count.

## 8. Alignment with the top-wrapper UVM

- Same vector family and generator as `tb_top_vec.hex`; the STR output at the wrapper is `str_sym_i/q` / `str_valid`.
- **Planned stage check in the top environment:** monitor `str_valid/str_sym` through the existing taps and compare with the order of `expected_out` from this sub-UVM (`tb_str_vec.hex`). This localizes a top-level failure to the STR in one step.
- Flush drive (`flush_active`) and repeat-pad is generated in the wrapper, so STR flush behavior must be re-verified there (TOP-DP-05).

## 9. Exit criteria

Golden PASS; every SVA passes, none vacuous; functional coverage 100 % with the added items; statement/branch/toggle targets met; STR-15…20 closed or justified.
