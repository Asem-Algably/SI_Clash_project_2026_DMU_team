# Verification Plan — Costas Loop (`costas_top`)

**Project:** Real-Time All-Digital Carrier & Timing Synchronization Unit (ERI – SI_CLASH)
**DUT:** `costas_top` = slicer → phase_error → pi_filter, plus two lock_detectors and quad_check
**Environment:** UVM, folder `costas_uvm/` · **Vectors:** `tb_costas_vec.hex` · **Coverage report supplied:** `coverage_rpt_costas_top.txt`
**Status legend:** `[DONE]` implemented in the delivered environment · `[PART]` partially implemented or not yet proven · `[PLAN]` planned, not implemented

> **How this plan was prepared.** No simulator was available. The plan is based on reading the RTL, the UVM sources, the golden vectors and the supplied coverage report. Two small Python models (one per block) were written from the RTL to cross-check the vectors; their results are in section 3.3. `[DONE]` means "coded and reviewed", not "passing". The first real regression is the first real evidence.

---

## 1. Scope and goals

1. Prove `freq_adj_o`, `phase_adj_o` (and the observation outputs `int_o`, `dbg_e_o`, lock and quadrant flags) match the golden reference for the reference burst (190-symbol preamble + 1200-symbol 16-QAM payload).
2. Prove each sub-block against its own specification: slicer decisions and tie rules, phase-error arithmetic, PI filter gains / clamps / anti-windup, quadrant resolution (k·π/2), both lock detectors.
3. Prove mode handling: HOLD clears all state, ACQ → TRACK switches gains and thresholds correctly, re-acquisition works.
4. Prove robustness: valid gaps and symbol spacing, input extremes, reset mid-burst, reserved encodings, X-freedom.
5. Reach the coverage targets of section 8.

**Out of scope here (covered elsewhere):** closed-loop convergence with the derotator (the UVM drives the Costas open-loop; see `derotator_verification_plan.md` and the top-wrapper plan), STR and coarse CFO.

---

## 2. DUT overview

### 2.1 Data flow

```
s_axis_i/q_sym (Q1.15), valid
   │
   ├─► slicer ──ai,aq──► phase_error (3 clk) ──e (Q1.15)──► pi_filter (3 clk) ──► freq_adj_o, int_o
   │     └─ sign flags ─► 1-stage reg (en = valid) ─────────► quad_check ──► phase_adj_o, quad_unresolved_o, done
   │
   ├─ kp/ki select (mode, slicer_qpsk, mod_type) ─► 3-stage delay ─► pi_filter
   ├─ lock_detector u_lock_int (internal, feeds quad_check) ─ lock_comb ─► quad_check
   └─ lock_detector u_lock_pub (public) ─► lock_o = done & !quad_unresolved & lock_pub
```

### 2.2 Ports

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `rst_ni` | in | 1 | Synchronous, active low |
| `s_axis_valid_i` | in | 1 | Symbol strobe (no ready) |
| `s_axis_i_sym_i`, `s_axis_q_sym_i` | in | s16 | Derotated symbol, Q1.15 |
| `mod_type_i` | in | 2 | `00` QPSK, `01` 16-QAM (`10`/`11` reserved) |
| `mode_i` | in | 2 | `00` HOLD, `01` ACQ, `10` TRACK (`11` reserved) |
| `slicer_qpsk_i` | in | 1 | Force QPSK decisions (preamble) |
| `preamble_end_i` | in | 1 | Forces the quadrant decision if not yet done |
| `costas_gain_i` | in | 8 | **Unused in the RTL** (see TOP plan, `loop_gain`) |
| `freq_adj_valid_o`, `freq_adj_o` | out | 1, s32 | PI output, Q0.32 turns/symbol, clamped to ±0.12 turn |
| `int_o` | out | s32 | Integrator value aligned with `freq_adj_o` |
| `phase_adj_valid_o`, `phase_adj_o` | out | 1, u32 | One-clock pulse; `[31:30]` = k, low 30 bits zero |
| `quad_unresolved_o` | out | 1 | Sticky until HOLD |
| `lock_o` | out | 1 | `done & !quad_unresolved & lock_pub` |
| `dbg_e_o`, `dbg_e_valid_o` | out | s16, 1 | Phase error (Q1.15) |
| `dbg_lock_int_o`, `dbg_quad_done_o` | out | 1, 1 | Internal lock, quadrant decision made |

### 2.3 Key parameters (RTL defaults)

| Parameter | Value | Note |
|---|---|---|
| `Qpsk_Level` / `Qam_Level` | 16384 / 5461 | ±0.5 and ±0.5/3 in Q1.15; 16-QAM boundary `T2 = 10922` |
| `Kp_Acq`, `Ki_Acq` | 220364, 7347 | Used in ACQ always |
| `Kp_Qpsk`, `Ki_Qpsk` | 220364, 7347 | Used outside ACQ when not QAM |
| `Kp_Qam`, `Ki_Qam` | 396656, 13224 | Used only when `!slicer_qpsk_i && mod_type_i == 01` and mode ≠ ACQ |
| `Max_Pi_Output` | `0x1EB851EB` | 0.12 turn/symbol clamp |
| `u_lock_pub` | α-shift 4, confirm 12, min symbols 15, init 8192 | Thresholds QPSK 3277 / 4915, QAM 1820 / 2731 (enter / exit) |
| `u_lock_int` | α-shift 4, confirm 12, min symbols 0, init 5734 | Thresholds 3277 / 4915 |

### 2.4 Latencies (from RTL reading, confirmed for `freq_adj` by the model in 3.3)

| Path | Clocks |
|---|---|
| `s_axis_valid_i` → `dbg_e_valid_o` | 3 |
| `dbg_e_valid_o` → `freq_adj_valid_o` | 3 (total 6 from `valid_i`) |
| `s_axis_valid_i` → `phase_adj_valid_o` | 4 |
| kp/ki delay line | 3 (advances every clock, not per valid) |

Two design assumptions follow from this and need explicit tests (COS-QD-09, COS-PI-06):

- The slicer sign register is a single stage enabled by `s_axis_valid_i`, while the error arrives 3 clocks later. The sign that quad_check sees is the right one only if symbols are at least 3 clocks apart. The system gives 4 clocks per symbol; the current directed sequence drives valid every clock.
- The gain pipeline is clock-based, so a mode change is seen by the PI filter 3 clocks late. This is correct for 4-clock spacing; behaviour at other spacings must be characterized.

### 2.5 Mode behaviour

| Mode | Behaviour |
|---|---|
| HOLD (00) | phase_error pipeline valids and `e_o` cleared, PI accumulator / output cleared, quad_check counters / `done` / `quad_unresolved` cleared, both lock detectors cleared |
| ACQ (01) | Acquisition gains, QPSK slicing during preamble (`slicer_qpsk_i = 1`) |
| TRACK (10) | QAM gains and thresholds if `mod_type_i = 01` and `slicer_qpsk_i = 0` |
| 11 | Reserved; behaves as non-HOLD, non-ACQ (needs a defined expectation, COS-MODE-04) |

---

## 3. Reference data

### 3.1 Vector format (`tb_costas_vec.hex`)

5624 rows, one per clock, 31 hex digits per row (underscores ignored):
`valid(1) I(4) Q(4) mode(1) preamble_end(1) mod_type(1) exp_freq_valid(1) exp_freq_adj(8) exp_phase_valid(1) exp_phase_adj(8) exp_lock(1)`

### 3.2 Measured facts

| Item | Value |
|---|---|
| Valid input symbols | 1298; first at row 388; 4-clock spacing (one 18-row gap at the start) |
| Mode | HOLD rows 0–381 · ACQ 382–765 · TRACK 766–5573 · HOLD 5574–5623 |
| `mod_type` | 01 (16-QAM) on every row |
| Expected `freq_adj` valid | 1294 (first at row 393); max \|freq_adj\| = `0x00AF8180` ≈ 0.0027 turn → **the 0.12-turn clamp is never reached by the golden run** |
| Expected `phase_adj` | one pulse at row 676, value `0x80000000` (k = 2) |
| `preamble_end_i` | one pulse at row 769, after `done`, so it is ignored by the RTL |
| Expected lock | rises at row 768, falls at row 5574 |
| `expected_metrics.txt` | `costas_lock_sym = 189`, `quad_k = 1`, `quad_unresolved = 0` |

Consistency with the other sub-UVMs (checked on the files): the derotator's expected output I/Q equals the Costas input I/Q row-for-row on all 1298 symbols; the Costas expected `freq_adj` equals the derotator's `freq_adj` input one row later on all 1294 values; the `phase_adj` pulse appears at row 676 here and 677 at the derotator. The vector family is consistent.

### 3.3 Independent cross-check (Python model written from the RTL)

| Check | Result |
|---|---|
| `freq_adj`, all 1294 expected values | **Bit-exact**, when the DUT value is read one clock after the vector row. This confirms slicer, phase error, gain selection and the PI filter, and shows the vector rows correspond to "DUT output sampled at posedge + 1" |
| `phase_adj` value | `0x80000000`, matches |
| `phase_adj` timing | Model pulses about one symbol later (row ≈ 680 vs 676) |
| Lock rise | Model `lock_o` rises at row 848 vs 768 in the vector (20 symbols later); fall at 5575 vs 5574 matches |

The last two rows are **open items (R1, R2 in section 12)**. They may be a model error on my side, an RTL / golden difference, or a different meaning of `exp_lock`. They are invisible today because the scoreboard compares neither lock nor pulse timing. They must be resolved by simulation, not assumed.

---

## 4. Environment as built, and review findings

### 4.1 Components

| Component | File | Behaviour |
|---|---|---|
| Interface | `costas_top_interface.sv` | All ports; no internal taps |
| Item | `costas_top_seq_item.sv` | Stimulus and observed fields |
| Sequences | `reset_seq`, `golden_seq`, `costas_directed_seq`, `main_seq` | 5 idle cycles; golden replay (`slicer_qpsk = mode != TRACK`, `costas_gain = 0`); directed (20 ACQ +,+ symbols, 16 alternating ±, 50 saturated ACQ symbols with 16-QAM, 20 idle); `main_seq` is **not used** by the test |
| Driver | `costas_top_driver.sv` | Drives all inputs at negedge |
| Monitor | `costas_top_monitor.sv` | Samples **outputs only** at posedge + 1 ns, every clock |
| Scoreboard | `costas_top_scoreboard.sv` | Compares `freq_adj` and `phase_adj` with `vec_mem[idx]`, `idx` = monitor sample count |
| Coverage | `costas_top_coverage.sv` + `costas_pkg.sv` | 8 covergroups in `costas_transaction` |
| SVA | `sva.sv` (bound into `costas_top`) | 3 assertions |
| Top | `costas_top_top.sv` | 8 ns clock; `rst_n` low for 100 ns |

### 4.2 Review findings (to fix before regression results are trusted)

| ID | Sev. | Finding | Evidence | Action |
|---|---|---|---|---|
| C-ENV-01 | High | The scoreboard pairs outputs with expectations by raw cycle index. Monitor index 0 is the first clock after time 0; vector row 0 is driven about 6 clocks later (5 `reset_seq` items plus negedge alignment). A check fires only when `exp_valid` and the DUT valid are high at the same index. With 4-clock symbol spacing, an offset that is not a multiple of 4 means the two never coincide, so **zero comparisons can happen and nothing fails** | `correct_count` in the run log is the symptom (0, or far below 1294 + 1) | Replace with order-based queues: the driver publishes the expected value with the stimulus, the scoreboard pops one expected value per DUT valid event. Add `leftover` and `extra` counters |
| C-ENV-02 | High | The scoreboard never checks `int_o`, `dbg_e_o`, lock, `lock_int`, `quad_done`, `quad_unresolved`; `v_exp_lock` is unpacked and unused; a missing output (expected valid, DUT silent) is not an error. The test only prints counts, so it also passes with 0 comparisons | `costas_top_scoreboard.sv`, `costas_top_test.sv` | Add a reference model (section 7.1) and a PASS rule that requires comparisons > 0, no leftover, no extra |
| C-ENV-03 | High | The monitor does not copy stimulus fields into the item, so every input-side covergroup samples undefined values | Report: `cg_ctrl`, `cg_valid_pre`, `cg_sym`, `cg_qam_points` are **0.00 %**; `cp_mode` bins in `cg_err` and `cg_pi` have 0 hits | Monitor both input and output sides (or take input fields from the driver's analysis port) |
| C-ENV-04 | Med | `cp_kp` samples a constant (`tr.kp = 24'd220364`), so bin `kp_qam` can never hit | Report: `kp_qam` 0 hits, `kp_acq_qpsk` 1439 | Sample the real `kp_d3` through a bind or tap |
| C-ENV-05 | Med | The DUT reset comes from `top.rst_n` only (released at 100 ns). `item.rst_n` is mirrored to the interface but does not reach the DUT, so reset-mid-burst tests are impossible. `reset_seq` never asserts reset. An `initial` block also rewrites all inputs at 100 ns, concurrently with the driver | `costas_top_top.sv`, `reset_seq.sv` | Drive the DUT-connected reset from the driver; add a real reset sequence |
| C-ENV-06 | Med | The directed sequence is unchecked, drives valid on consecutive clocks (outside the system's 4-clock spacing), and per the report it did not reach `quad_unresolved`, k = 0 / 1, or the positive integrator band | Report: `cp_unres.unresolved` 0, `k0`/`k1` 0, `cp_int.pos_high` 0 | Rebuild as self-checking directed tests (section 6) |
| C-ENV-07 | Low | `main_seq.sv` is compiled but unused; `costas_gain_i` is never varied | | Use or remove |
| C-ENV-08 | Low | SVA contains only 3 assertions | `sva.sv` | Extend (section 7.2) |

---

## 5. Feature list and traceability

### 5.1 Reset and mode control

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-RST-01 | After `rst_ni` low every output is 0 / de-asserted; kp/ki delay line holds the ACQ gains | SVA + model | [PLAN] |
| COS-RST-02 | Reset in the middle of TRACK, then a clean second burst matches the golden | Directed (needs C-ENV-05 fix) | [PLAN] |
| COS-MODE-01 | HOLD clears: `e_o`, `dbg_e_valid_o`, PI accumulator and output, counters, `done`, `quad_unresolved`, `lock_o`, `dbg_lock_int_o`, `phase_adj_*` | Directed + SVA | [PART] (HOLD occurs in golden, never checked) |
| COS-MODE-02 | HOLD → ACQ → TRACK → HOLD sequence matches golden | Golden | [PART] |
| COS-MODE-03 | Re-acquisition: second ACQ after HOLD starts from clean state | Golden twice | [PLAN] |
| COS-MODE-04 | `mode_i = 11` and `mod_type_i = 10/11`: no X, defined behaviour (reserved encodings treated as non-QAM / non-ACQ) | Directed | [PLAN] |
| COS-MODE-05 | One-clock HOLD glitch in the middle of a burst clears state exactly once | Directed | [PLAN] |

### 5.2 Slicer

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-SLC-01 | QPSK: decision ±16384 by sign; 0 → +16384 | Model compare on `dbg_e_o` | [PLAN] |
| COS-SLC-02 | 16-QAM: inner ±5461, outer ±16384; boundaries `+T2 → outer`, `−T2 → inner`, `0 → +inner`; test `T2−1, T2, T2+1, −T2−1, −T2, −T2+1, 0, −1, 0x7FFF, 0x8000` per axis | Directed sweep + model | [PLAN] |
| COS-SLC-03 | `slicer_qpsk_i = 1` forces QPSK decisions even if `mod_type_i = 01` | Directed | [PLAN] |
| COS-SLC-04 | Sign flags = `~sign bit` (0 counts as positive) | Via quad_check results | [PLAN] |

### 5.3 Phase error

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-PE-01 | `e = sat16((yq·ai − yi·aq) >>> 15)`, truncation, bit-exact over all 16-QAM points with noise and all QPSK points | Model on `dbg_e_o` | [PLAN] |
| COS-PE-02 | Latency 3 clocks; `dbg_e_valid_o` follows `valid_i` exactly 3 clocks later, also for back-to-back and gapped valids | SVA | [PLAN] |
| COS-PE-03 | Saturation branches (`E_MAX` / `E_MIN`) | Analysis | [PART] — with slicer-generated `ai`/`aq` (≤ 16384) the error is bounded by 16384 in magnitude, so the clamp **cannot fire through the slicer path**. Prove it (SVA / formal on \|e\| ≤ 16384) and waive the two branches with that justification, or cover them in a block-level test of `phase_error` |
| COS-PE-04 | `e_o` holds between valids; cleared by HOLD | SVA | [PLAN] |

### 5.4 PI filter

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-PI-01 | `freq_adj_o` bit-exact vs golden for all 1294 symbols | Scoreboard | [PART] (coded; alignment unproven, C-ENV-01) |
| COS-PI-02 | `int_o` aligned with `freq_adj_valid_o` (value = accumulator after that sample) | Model | [PLAN] |
| COS-PI-03 | Gain selection: ACQ → `Kp/Ki_Acq`; non-ACQ and `use_qam` → QAM gains; otherwise QPSK gains | Model + tap on `kp_d3` | [PLAN] |
| COS-PI-04 | Integrator clamp at ±`Max_Pi_Output`: drive a constant maximum phase offset until the integrator saturates (about 300 symbols with QAM gains, about 550 with ACQ gains at e ≈ 0.5), both polarities | Directed DC-offset | [PLAN] |
| COS-PI-05 | Anti-windup: while the output is saturated and the error keeps the same sign, the integrator freezes; it resumes when the error flips | Directed + model | [PLAN] |
| COS-PI-06 | Gain switch at ACQ → TRACK: new gains reach the filter 3 clocks late; check at 4-clock spacing (system) and characterize at other spacings | Directed | [PLAN] |
| COS-PI-07 | Output clamp ±`Max_Pi_Output` flags (`sat_pos/neg`) and recovery | Directed | [PLAN] |
| COS-PI-08 | Sign convention: positive error gives positive `freq_adj` | Model | [PLAN] |
| COS-PI-09 | Latency 3 clocks after `dbg_e_valid_o`; output holds when no valid | SVA | [PLAN] |
| COS-PI-10 | Back-to-back valids accumulate correctly (valid every clock) | Directed | [PLAN] |

### 5.5 Quadrant check

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-QD-01 | Decision by a full counter (golden: pulse at row 676, `0x80000000`) | Golden | [PART] |
| COS-QD-02 | Decision by `preamble_end_i` when no counter is full | Directed | [PLAN] |
| COS-QD-03 | All four results: `phase_adj[31:30]` = 00, 01, 10, 11 for (I, Q) signs (+,+), (−,+), (−,−), (+,−) | Directed, four rotations of the constellation | [PLAN] (report: only k2 and k3 were hit) |
| COS-QD-04 | Unresolved when a counter is 0 at evaluation: `quad_unresolved_o = 1`, no `phase_adj` pulse, sticky until HOLD | Directed (equal + and − signs) | [PLAN] (report: never reached) |
| COS-QD-05 | `phase_adj_valid_o` is a single-clock pulse; low 30 bits of `phase_adj_o` are zero | SVA | [PLAN] |
| COS-QD-06 | Counters saturate at +15 / −16 | Directed | [PLAN] |
| COS-QD-07 | Counters clear while `lock_int_comb` is low; do not count without `e_valid` | Directed | [PLAN] |
| COS-QD-08 | `done` is sticky: later `preamble_end_i` pulses and sign changes do not re-trigger | Golden (pulse at 769) + directed | [PART] |
| COS-QD-09 | Sign / error alignment: results are correct for symbol spacing 3, 4, 5 and random gaps; characterize spacing 1 and 2 (expected misalignment, see 2.4) | Directed spacing sweep | [PLAN] |
| COS-QD-10 | `preamble_end_i` while the loop is not locked gives `quad_unresolved_o` | Directed | [PLAN] |
| COS-QD-11 | Mapping to `expected_metrics.txt`: the vector shows `0x80000000` (k = 2) while the file says `quad_k = 1`; define the convention | Review with model owner | [PLAN] |

### 5.6 Lock detectors and `lock_o`

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-LCK-01 | `lock_o = done & !quad_unresolved & lock_pub` | SVA (two implications exist) + equality | [PART] |
| COS-LCK-02 | Lock timing vs golden `exp_lock` (rise row 768, fall row 5574) | Scoreboard on lock edges | [PLAN]; see R2 |
| COS-LCK-03 | EMA / leaky bucket: +1 on good, −2 on bad, saturate at confirm count, lock at confirm, unlock at 0; threshold switches enter ↔ exit with state | Model + directed error profiles | [PLAN] |
| COS-LCK-04 | `u_lock_pub` min-symbol rule (15) and clear conditions (`HOLD`, `!done`, `quad_unresolved`) | Directed | [PLAN] |
| COS-LCK-05 | Threshold set follows `use_qam`; at the preamble → payload switch lock must not drop in the golden run | Golden + model | [PART] |
| COS-LCK-06 | `u_lock_int` stops updating once `done` (valid gated by `!done`) and holds | Directed | [PLAN] |
| COS-LCK-07 | Lock loss during TRACK: inject a noise / phase-jump burst, `lock_o` falls, then re-locks | Directed (this is the uncovered `<fall, done, ok>` bin) | [PLAN] |
| COS-LCK-08 | HOLD and `quad_unresolved` force `lock_o` low | Directed | [PLAN] |

### 5.7 Protocol, robustness, observability

| ID | Feature | Method | Status |
|---|---|---|---|
| COS-ROB-01 | No X on `freq_adj_o` when valid | SVA `a_no_x_freq` | [DONE] |
| COS-ROB-02 | No X on `phase_adj_o`, `dbg_e_o`, `int_o`, lock and flag outputs; no X on inputs after reset | SVA | [PLAN] |
| COS-ROB-03 | Symbol spacing sweep (1, 2, 3, 4, 5, random 1–20) with golden-style stimulus; outputs match the model | Directed / random | [PLAN] |
| COS-ROB-04 | Input extremes: 0x8000, 0x7FFF, 0, constant DC, alternating full scale | Directed | [PLAN] |
| COS-ROB-05 | `costas_gain_i` has no effect (toggle it during a golden replay) | Directed + assertion | [PLAN] |
| COS-ROB-06 | Spurious `preamble_end_i` pulses in each mode, repeated pulses | Directed | [PLAN] |
| COS-ROB-07 | Back-to-back bursts through HOLD: second burst matches golden | Golden twice | [PLAN] |
| COS-ROB-08 | QPSK-payload burst (`mod_type = 00` in TRACK): QPSK gains and thresholds | Model-based random (no QPSK vectors exist) | [PLAN] |
| COS-ROB-09 | Output stability: `freq_adj_o` and `int_o` hold between valids | SVA | [PLAN] |

### 5.8 Integration cross-references

| ID | Feature | Where |
|---|---|---|
| COS-INT-01 | Costas feedback closes the loop with the derotator; residual CFO / phase error converge | `derotator_verification_plan.md` (DER-DP-04), top plan (TOP-DP-12) |
| COS-INT-02 | In the wrapper, `slicer_qpsk = (fsm_state != Track)` and `mod_type` is delayed 10 clocks; the Costas must be correct under that exact stimulus | TOP-DP-06, TOP-DP-07 |

---

## 6. Test list

| Test / option | Stimulus | Checking | Status |
|---|---|---|---|
| `costas_top_test` (default) | `reset_seq` → `golden_seq` → `costas_directed_seq` → 1000 ns | `freq_adj`, `phase_adj` per cycle index | [PART] (C-ENV-01 / 02) |
| `t_golden` | Golden replay with the order-based scoreboard | Bit-exact `freq_adj`, `int_o`, `dbg_e_o`, `phase_adj`; lock edges (informational first) | [PLAN] |
| `t_golden_x2` | Golden twice with idle between | Both bursts match | [PLAN] |
| `t_hold_clear` | Mid-burst HOLD pulse, then continue | Clear behaviour, clean restart | [PLAN] |
| `t_slicer_sweep` | Boundary and corner values, QPSK and QAM | `dbg_e_o` vs model | [PLAN] |
| `t_pi_sat_pos` / `t_pi_sat_neg` | Constant ±maximum phase offset, > 600 symbols | Clamp, anti-windup, recovery | [PLAN] |
| `t_gain_switch` | ACQ → TRACK with spacing 4 and others | `freq_adj` vs model | [PLAN] |
| `t_quad_k0` … `t_quad_k3` | Constellation rotated by 0 / 90 / 180 / 270° | `phase_adj[31:30]` | [PLAN] |
| `t_quad_preamble_end` | No counter fills before `preamble_end_i` | Decision by `preamble_end_i` | [PLAN] |
| `t_quad_unres` / `t_quad_nolock` | Zero sign balance; `preamble_end_i` without lock | `quad_unresolved_o`, no pulse | [PLAN] |
| `t_lock_hyst` / `t_lock_loss` | Error profiles around enter / exit thresholds; noise burst in TRACK | Lock edges vs model | [PLAN] |
| `t_spacing` | Spacing 1…5 and random | Outputs vs model, characterization of spacing < 3 | [PLAN] |
| `t_extremes` | Full-scale and DC inputs | No X, clamps, bounded loop | [PLAN] |
| `t_reset_mid` | `rst_ni` pulse in TRACK, then golden | Clean second burst | [PLAN] |
| `t_reserved` | `mode_i = 11`, `mod_type_i = 10/11`, gain toggling | No X, defined behaviour | [PLAN] |
| `t_random_rm` | Constrained-random (`costas_transaction` constraints) vs reference model | Full scoreboard | [PLAN] |

Regression: golden, golden ×2, then every directed test with its own seed; merge UCDBs before reading coverage closure numbers.

---

## 7. Checkers

### 7.1 Scoreboard (to be built)

A transaction-level reference model of the Costas inside the scoreboard, driven by the stimulus the driver publishes, comparing the monitor's output events in order:

| Check | Severity |
|---|---|
| `freq_adj_o`, `int_o` equal model on every `freq_adj_valid_o` | `uvm_error` |
| `dbg_e_o` equals model on every `dbg_e_valid_o` | `uvm_error` |
| `phase_adj_o` equals model; exactly one pulse per burst (or `quad_unresolved_o`) | `uvm_error` |
| Missing or extra output events (leftover / extra counters) | `uvm_error` / FAIL in `report_phase` |
| Lock and quad flags vs model; vs golden `exp_lock` at edges (informational until R2 is resolved) | `uvm_error` / info |
| PASS rule | PASS only if comparisons > 0, no mismatch, no extra, no leftover |

The golden vector remains the reference for the reference burst. The model extends checking to stimulus that has no vector. The Python model of section 3.3 reproduces `freq_adj` exactly and is a starting point for the SV model.

### 7.2 SVA

Existing (`sva.sv`): `a_lock_done`, `a_lock_no_unres`, `a_no_x_freq`.

Planned: `lock_o` equality; no X on all outputs; `phase_adj_valid_o` one-clock pulse and zero low bits; `dbg_e_valid_o` 3 clocks after `valid_i`; `freq_adj_valid_o` 3 clocks after `dbg_e_valid_o`; HOLD clears outputs one clock later; \|freq_adj\| ≤ `Max_Pi_Output`; \|e\| ≤ 16384 (justifies waiver COS-PE-03); `quad_unresolved_o` sticky; `done` sticky; `costas_gain_i` has no effect.

---

## 8. Coverage plan

### 8.1 Functional coverage (existing, from the supplied report)

8 covergroups, 121 bins, 31 hit (25.61 %), group average **22.41 %**.

| Group | Report | Reason / action |
|---|---|---|
| `cg_ctrl`, `cg_valid_pre`, `cg_sym`, `cg_qam_points` | 0.00 % | Monitor does not fill stimulus fields (C-ENV-03) |
| `cg_err` | 33.33 % | `cp_e` 100 %; mode bins and cross need stimulus fields |
| `cg_pi` | 45.00 % | `kp_qam` dummy (C-ENV-04); `cp_int.pos_high` never reached |
| `cg_lock` | 84.28 % | `quad_unresolved` never reached; `<fall, done, ok>` (lock loss in TRACK) never reached |
| `cg_quad` | 16.66 % | k0, k1 never reached; `cp_trig` 0 (stimulus field missing) |

Additions: symbol spacing bins (1, 2, 3, 4, 5–20); `mod_type` reserved values; `mode_i = 11`; PI saturation flags (`sat_pos`, `sat_neg`, freeze active); gain-select cross (mode × use_qam); lock transitions × mode; quad result × trigger (counter full / `preamble_end_i`); integrator magnitude bins up to the clamp; error sign × mode.

Expected waivers (with written justification): `phase_error` clamp branches (COS-PE-03); cross bins excluded as illegal in `cx_lock_state` and `cx_mode_slq`; high toggle bits of `int_o` / `freq_adj_o` above the clamp range.

### 8.2 Code coverage (supplied report, per instance) and targets

| Instance | Stmt | Branch | Cond | Expr | Toggle |
|---|---|---|---|---|---|
| `u_slicer` | 100 | 100 | 100 | 100 | 100 |
| `u_pe` | 91.3 | 83.3 | 33.3 | – | 99.8 |
| `u_pi` | 83.3 | 73.7 | 20.0 | 33.3 | 86.9 |
| `u_lock_int` | 90.0 | 90.0 | 80.0 | 80.0 | 67.4 |
| `u_quad` | 97.2 | 81.5 | 42.9 | 66.7 | 54.3 |
| `u_lock_pub` | 100 | 100 | 100 | 83.3 | 78.8 |
| `costas_top` | 100 | 100 | 100 | 81.8 | 62.9 |

Whole report, filtered view: **66.14 %**. Targets: statement ≥ 95 %, branch ≥ 90 %, condition / expression ≥ 85 %, toggle ≥ 80 % with documented waivers. The gaps map to the missing tests: PI clamp / freeze paths (`t_pi_sat_*`), quad unresolved and preamble-end paths, lock loss, reserved encodings.

### 8.3 Assertion coverage

3 / 3 assertions covered in the supplied report with no failures. Target after extension: 100 % attempted, 0 failures, no vacuous passes.

---

## 9. Assumptions and known limitations

1. The UVM drives the Costas **open-loop**: the symbol input does not depend on `freq_adj_o` / `phase_adj_o`. Loop dynamics are verified with the derotator and at top level.
2. The golden vector covers one scenario: 16-QAM, one CFO, one timing offset, 4-clock spacing, k = 2, no PI saturation, no lock loss. Everything else depends on the reference model (7.1) or new vectors.
3. `slicer_qpsk_i = (mode != TRACK)` in `golden_seq` mirrors the wrapper (`fsm_state != Track`); the vector does not carry it.
4. Symbol spacing ≥ 3 clocks is assumed legal (2.4); spacing 1 and 2 are characterized, not required to pass, until the designers confirm the intended range.
5. `costas_gain_i` is treated as unused, as the RTL does.
6. Encodings `mode_i` / `mod_type_i` marked "TBD with organizers" in the RTL must be re-checked when confirmed.

---

## 10. Running

```
cd costas_uvm
vsim -do run.do            # vlib, vlog -f src_files.list +cover -covercells, vsim -cover,
                           # run -all, vcover report -details -all -> coverage_rpt_costas_top.txt
```

`tb_costas_vec.hex` must be in the simulation directory. Planned plusargs: `+TEST=<name>`, `+SEED=<n>`, `+SPACING=<n>`. Keep `src_files.list` order: interface and SVA, `costas_pkg.sv`, config and item, sequences, components, test, RTL, top.

---

## 11. Exit criteria

- Golden test PASS with **comparisons > 0**: 0 mismatches, 0 extras, 0 leftover; `freq_adj` 1294 / 1294, `phase_adj` 1 / 1.
- Every `COS-*` item is implemented and passing, or closed with a written justification.
- All SVA pass, none vacuous.
- Functional coverage 100 % with justified exclusions; code-coverage targets of 8.2 met on the merged database.
- R1 and R2 (phase_adj timing, lock timing) explained, not waived.

---

## 12. Risks and open items

| # | Item | Impact | Action |
|---|---|---|---|
| R1 | `phase_adj` pulse in the vector (row 676) vs the RTL model (about one symbol later) | Possible RTL / golden mismatch hidden by the scoreboard | Simulate, compare counter values per symbol with the MATLAB model |
| R2 | `exp_lock` rises at row 768, model `lock_o` at 848; `expected_metrics.txt` says `costas_lock_sym = 189` | Lock definition or detector parameters may differ from golden | Confirm which lock the vector column represents (`lock_int`, `lock_pub`, top-level `lock_detect`) |
| R3 | Scoreboard may perform zero comparisons (C-ENV-01) | A regression could pass while checking nothing | Fix first; add non-vacuity rule |
| R4 | `quad_k = 1` in `expected_metrics.txt` vs `0x80000000` in the vector | Wrong convention in documentation or model | COS-QD-11 |
| R5 | Sign register alignment needs symbol spacing ≥ 3 clocks | Latent bug if the wrapper ever changes spacing | COS-QD-09 and a design note |
| R6 | Single golden scenario | Escapes in other CFO / noise / modulation cases | Reference-model random tests; new vectors from the MATLAB model |
| R7 | `costas_gain_i` unused | Gain changes cannot be verified | Re-plan when wired |
| R8 | Reserved encodings TBD | Mis-decode if encodings change | Re-run on update |
