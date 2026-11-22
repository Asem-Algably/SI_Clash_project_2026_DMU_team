# Verification Plan — Derotator (`derotator`)

**Project:** Real-Time All-Digital Carrier & Timing Synchronization Unit (ERI – SI_CLASH)
**DUT:** `derotator` = `freq_word` → `NCO_accumulator` → `lut_rom` + `quadrant_rotator` + `input_pipeline` → `complex_multiplier`
**Environment:** UVM, folder `derotator_uvm/` · **Vectors:** `tb_derot_vec.hex` · **Coverage report supplied:** `coverage_rpt_derotator.txt`
**Status legend:** `[DONE]` implemented in the delivered environment · `[PART]` partially implemented or not yet proven · `[PLAN]` planned, not implemented

> **How this plan was prepared.** No simulator was available. The plan is based on reading the RTL, the UVM sources, the golden vector and the supplied coverage report. A small independent Python model of the derotator was written from the RTL and run against the golden vector (section 3.3). `[DONE]` means "coded and reviewed", not "passing".

---

## 1. Scope and goals

1. Prove the derotated symbols match the golden reference bit-exactly for the reference burst.
2. Prove each block against its specification: frequency-word composition and override, NCO accumulation and wrap, one-shot phase correction, ROM contents, quadrant rotation with saturating negate, multiplier arithmetic and saturation, 3-clock latency.
3. Prove behaviour under every valid pattern (back-to-back, 4-clock spacing, random gaps) and with control pulses that coincide.
4. Prove robustness: input extremes, reset mid-stream, force override on and off, X-freedom.
5. Reach the coverage targets of section 8, including a full sweep of the 4096-entry ROM.

**Out of scope here:** Costas loop behaviour (see `costas_verification_plan.md`) and loop convergence with the Costas closed (DER-DP-05 and the top plan, TOP-DP-12).

---

## 2. DUT overview

### 2.1 Data flow

```
coarse_word (s24) ─┐                      ┌── force_freq (DFT override, priority)
freq_adj (s32) ────┼─► freq_word ─1 clk─► freq_word_o ─► NCO_accumulator ─► phase_o (u32)
                   │   coarse<<8 + adj                     phase += valid ? fcw : 0
phase_adj (u32) ───┴──────────────────────────────────►          + (rising edge of phase_adj_valid ? phase_adj : 0)
                                                        quad = phase[31:30], idx = phase[29:18]
s_axis i/q ──► quadrant_rotator (comb, x·(−j)^q) ──► input_pipeline (1 clk) ──┐
                       lut_rom (1 clk): s0 = S[idx], c0 = S[~idx] ────────────┴─► complex_multiplier (2 clk) ─► m_axis i/q
```

Operation: `y = x · e^(−jθ)`. The quadrant is applied to the input (x' = x·(−j)^q), so the multiplier always uses the 0–90° table values:
`y_re = x'_re·c0 + x'_im·s0`, `y_im = x'_im·c0 − x'_re·s0`.

### 2.2 Ports

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `rst_ni` | in | 1 | Synchronous, active low |
| `s_axis_valid_i`, `s_axis_i_sym_i`, `s_axis_q_sym_i` | in | 1, s16, s16 | Symbol strobe and Q1.15 symbol (no ready) |
| `coarse_valid_i`, `coarse_word_i` | in | 1, s24 | One pulse; 2^24 = one turn per symbol |
| `freq_adj_valid_i`, `freq_adj_i` | in | 1, s32 | Costas correction, 2^32 = one turn; last valid value is held |
| `force_freq_en_i`, `force_freq_i` | in | 1, u32 | DFT override of the frequency word |
| `phase_adj_valid_i`, `phase_adj_i` | in | 1, u32 | One-time k·π/2 correction; only the **rising edge** is used |
| `m_axis_valid_o`, `m_axis_i_sym_o`, `m_axis_q_sym_o` | out | 1, s16, s16 | Derotated symbol, Q1.15 |
| `phase_o`, `freq_word_o` | out | u32, u32 | Observation (DFT mux) |

### 2.3 Parameters

`Width = 32`, `Phase_Bits = 12` (table index), `DataWidth = 16`, `Frac = 15`, `Coarse_W = 24`, `Coarse_Shift = 8`. The ROM content is generated for `Phase_Bits = 12` and `DataWidth = 16` only (the module raises `$error` otherwise).

### 2.4 Timing

| Path | Clocks |
|---|---|
| `s_axis_valid_i` → `m_axis_valid_o` | 3 (ROM / input pipeline 1, multiplier 2) |
| `coarse_valid_i` or `freq_adj_valid_i` → `freq_word_o` | 1 (the new value is used in the same cycle it arrives, then registered) |
| `phase_adj_valid_i` rising edge → `phase_o` | 1 |

The quadrant and table index of a symbol come from `phase_o` **before** that symbol's increment, so a `phase_adj` pulse that coincides with a valid symbol takes effect from the next symbol. The frequency word seen by the NCO is the registered `freq_word_o`.

### 2.5 Behaviour details that need explicit tests

- Datapath registers (ROM output, input pipeline data, multiplier products and outputs) have **no reset** and load only on valid; they are X until the first valid symbol. Only valid-qualified outputs may be checked.
- `quadrant_rotator` negates with saturation: `−(−32768) = +32767`, an error of 1 LSB only when an input is exactly −1.0, "and the reference model must do the same".
- `complex_multiplier` right-shifts the 33-bit sum by 15 (**truncation**, floor) and saturates to ±32768 / 32767. The header comment says "round half up"; the code and the golden vector use truncation (3.3).
- `freq_word` adds with natural 32-bit wrap; the NCO wraps at 2^32.
- `phase_adj_valid_i` held high adds the correction once; it must go low before the next correction.
- `lut_rom` entries: `S[a] = round(sin((a + 0.5)·(π/2)/4096)·32767)`; `cos = S[~a]`.

---

## 3. Reference data

### 3.1 Vector format (`tb_derot_vec.hex`)

5624 rows, one per clock, 43 hex digits per row, **nibble-aligned** fields (underscores ignored):
`valid(1) I(4) Q(4) coarse_valid(1) coarse_word(6) freq_adj_valid(1) freq_adj(8) phase_adj_valid(1) phase_adj(8) exp_valid(1) exp_I(4) exp_Q(4)`
(172 bits in total). **There are no force-override fields in the file.**

### 3.2 Measured facts

| Item | Value |
|---|---|
| Valid inputs | 1299: rows 385 … 5591, 4-clock spacing (one 18-row gap) |
| Expected outputs | 1298, each exactly 3 rows after its input (rows 388 … 5590). **The last valid input (row 5591) has no expected output** |
| Coarse word | one pulse at row 380, value 1093103 (`0x10ADEF`, ≈ 0.0652 turn/symbol), before the first symbol |
| `freq_adj` | 1294 valid pulses, rows 394 + 4k, never on the same row as a valid symbol; first −9103104, last `0xFFDB0113` |
| `phase_adj` | one pulse at row 677, `0x80000000` (0.5 turn), **on a valid-symbol row** |
| Force override | never used |
| Input range | I −24835 … 25155, Q −25866 … 25428 |
| Expected output range | ±19823; no saturation and no −32768 anywhere |

Consistency with the Costas vector (checked on the files): expected derotator output = Costas input on all 1298 symbols; Costas `freq_adj` appears at the derotator one row later on all 1294 values; the `phase_adj` pulse is at row 676 for the Costas and 677 here.

### 3.3 Independent cross-check (Python model written from the RTL)

| Check | Result |
|---|---|
| `lut_rom` table (`sine_quarter_lut.svh`) vs `round(sin((a+0.5)·π/2/4096)·32767)` | 4096 / 4096 entries identical; monotonic; min 6, max 32767 |
| Clock-accurate model (freq word, NCO, ROM, quadrant rotator, pipeline, multiplier) vs the 1298 expected outputs, **truncation** | **0 mismatches** |
| Same model with round-half-up | 965 mismatches of 1298 |
| Model output count | 1299 (the extra output comes from the unpaired last input) |

Conclusions: the RTL and the golden agree on this scenario; the "round half up" wording in the RTL comments is wrong; and one output has no golden partner (open item R2).

---

## 4. Environment as built, and review findings

### 4.1 Components

| Component | File | Behaviour |
|---|---|---|
| Interface | `derotator_interface.sv` | All ports; `initial` block zeroes inputs |
| Item | `derotator_seq_item.sv` | Randomizable inputs, outputs, `exp_i`, `exp_q` |
| Sequences | `golden_seq.sv` (used), `derotator_seq.sv`, `reset_seq.sv` (not used) | Golden replay of `tb_derot_vec.hex` |
| Driver | `derotator_driver.sv` | Holds `rst_ni` low until the first negedge (about one clock); drives every row at negedge and sends it to the scoreboard |
| Monitor | `derotator_monitor.sv` | At posedge; publishes an item **only when** `m_axis_valid_o = 1` |
| Scoreboard | `derotator_scoreboard.sv` | Queue of driven items, popped on each output |
| Coverage | `derotator_coverage.sv` | 5 covergroups on the monitor item |
| SVA | `sva.sv` (bound into `derotator`) | `a_known_out`, `a_valid_origin` |
| Test | `derotator_test.sv` | Golden sequence, 10-clock drain, prints SUCCESS if `wrong_count == 0` |
| Top | `derotator_top.sv` | 20 ns clock |

### 4.2 Review findings (to fix before regression results are trusted)

| ID | Sev. | Finding | Evidence | Action |
|---|---|---|---|---|
| D-ENV-01 | **High** | `golden_seq` unpacks the row as a **bit-packed 189-bit** concatenation with `force_freq_en` and a 32-bit `force_freq`. The file is **nibble-aligned, 172 bits, and has no force fields**. Only `exp_i` / `exp_q` (lowest 32 bits) decode correctly; `valid`, `I`, `Q`, `coarse`, `freq_adj`, `phase_adj` are mis-decoded, so the DUT is not driven with the golden stimulus | Vector layout (3.1) vs the concatenation in `golden_seq.sv`; the supplied report (older build) shows `lut_rom` 1 of 4096 branches hit and multiplier toggle 0.65 %, consistent with a barely stimulated datapath | Unpack as `{valid[3:0], I, Q, cv[3:0], cword, fav[3:0], fadj, pav[3:0], padj, ev[3:0], eI, eQ} = vec_mem[i][171:0]` and add a row-count / field sanity check (valid never X) |
| D-ENV-02 | **High** | The scoreboard pushes **every driven row** into `expected_queue` (5624 rows) but pops only on valid outputs (about 1298). Outputs are therefore compared with the wrong rows | `write_drv` / `write_mon` | Push an expectation only when `exp_valid = 1` (add the field to the item); keep order-based pairing |
| D-ENV-03 | High | PASS rule is `wrong_count == 0`: a run with zero comparisons, missing outputs or extra outputs prints SUCCESS. No `leftover` / `extra` check; counters are `static` | `derotator_test.sv` | PASS only if comparisons > 0, no mismatch, queue empty at end, no extra output |
| D-ENV-04 | High | The monitor publishes only on `m_axis_valid_o` and copies just a few fields. `cg_in_valid` cannot see gaps, `cg_input_sym` and `cg_freq` sample undefined values, and `cg_nco` samples `phase_o` at output time with the `iff` using the wrong cycle's `valid` | `derotator_monitor.sv`, `derotator_coverage.sv` | Sample stimulus at the driver (analysis port) or with an input monitor; sample `phase_o[31:30]` at the symbol's input cycle |
| D-ENV-05 | Med | `rst_ni` is held low only until the first negedge (one rising edge) and `item.rst_ni` is never driven, so reset-mid-stream tests are impossible | `derotator_driver.sv` | Drive `rst_ni` from the item; longer initial reset |
| D-ENV-06 | Med | The supplied coverage report is from an **earlier build**: it lists an assertion `a_force_freq` (897 failures, 0 passes) and a covergroup `g1` (14 bins, 0 %) that are not in the current sources; total coverage 5.80 % | Report vs `sva.sv`, `derotator_coverage.sv` | Regenerate the report on the current code; check whether the dropped `force_freq` assertion should return |
| D-ENV-07 | Med | SVA has two assertions; `force_freq_en_i`, `force_freq_i` and `freq_word_o` are bound but unused | `sva.sv` | Extend (7.2) |
| D-ENV-08 | Med | Only one test exists: golden replay. No directed, force / DFT, gap, extreme or random stimulus | `derotator_test.sv` | Section 6 |
| D-ENV-09 | Low | `derotator_seq.sv` reads a 4-field format that does not match the vector and is not compiled; `reset_seq.sv` randomizes all inputs and is unused | | Remove or fix |
| D-ENV-10 | Low | The golden has one more valid input than expected outputs (R2) | 3.2 | Decide the expected behaviour and encode it |

---

## 5. Feature list and traceability

### 5.1 Reset

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-RST-01 | After reset: `freq_word_o = 0`, `phase_o = 0`, `m_axis_valid_o = 0`, `adj_reg = 0`, `coarse_reg = 0`, `phase_adj_valid_q = 0` | SVA + directed | [PLAN] |
| DER-RST-02 | Reset in the middle of a stream, then a clean golden run matches | Directed (needs D-ENV-05 fix) | [PLAN] |
| DER-RST-03 | No valid output after reset until a valid input has propagated | SVA | [PART] (`a_valid_origin`, one direction only) |

### 5.2 Frequency word (`freq_word`)

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-FW-01 | `coarse_word` scaled by 2^8, sign kept; test 0, 1, −1, `0x7FFFFF`, `0x800000` | Directed + model | [PLAN] |
| DER-FW-02 | Coarse bypass: `coarse_valid_i` affects `freq_word_o` one clock later; reload with a second pulse replaces the first, held `freq_adj` kept | Directed | [PLAN] |
| DER-FW-03 | `freq_adj` held until the next valid; used in the arrival cycle | Directed | [PLAN] |
| DER-FW-04 | `coarse_valid_i` and `freq_adj_valid_i` in the same cycle | Directed | [PLAN] |
| DER-FW-05 | 32-bit wrap of coarse + adj (positive and negative overflow) | Directed | [PLAN] |
| DER-FW-06 | Force override: `force_freq_en_i` gives `freq_word_o = force_freq_i` one clock later, priority over the normal path; release returns to the normal path | Directed + SVA | [PLAN] |
| DER-FW-07 | Force value reaches the NCO increment | Directed | [PLAN] |

### 5.3 NCO accumulator

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-NCO-01 | `phase += freq_word_o` on valid symbols only; holds otherwise | SVA + model | [PLAN] |
| DER-NCO-02 | Wrap at 2^32; quadrant boundaries crossed in both directions (positive and negative frequency) | Directed | [PLAN] |
| DER-NCO-03 | `phase_adj` one-shot on the rising edge: held-high adds once; high-low-high adds twice; values `0`, `0x40000000`, `0x80000000`, `0xC0000000` and arbitrary | Directed | [PLAN] |
| DER-NCO-04 | `phase_adj` coincident with a valid symbol (golden does this at row 677) and not coincident | Golden + directed | [PART] |
| DER-NCO-05 | `quad_o = phase[31:30]`, `lut_idx_o = phase[29:18]`, low 18 bits dropped | Model + SVA | [PLAN] |
| DER-NCO-06 | Symbol uses the pre-increment phase | Model | [PLAN] |
| DER-NCO-07 | `phase_o` and `freq_word_o` observation outputs equal the internal values | SVA | [PLAN] |

### 5.4 Lookup table (`lut_rom`)

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-ROM-01 | All 4096 entries equal `round(sin((a+0.5)·π/2/4096)·32767)` (checked on the file: 0 differences) | Tap on `sin_o` / `cos_o` vs a TB-computed formula | [PART] (offline check done, in-TB check [PLAN]) |
| DER-ROM-02 | `cos_o = S[~a]`; range 0 … 0x7FFF; monotonic | Tap + SVA | [PLAN] |
| DER-ROM-03 | One-clock registered read, only when `s_axis_valid_i`, holds otherwise | SVA | [PLAN] |
| DER-ROM-04 | Every index 0 … 4095 addressed through the full datapath, in every quadrant | `t_lut_sweep` (6.1) | [PLAN] |

### 5.5 Quadrant rotator and input pipeline

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-QR-01 | `q = 0..3` give `(xi, xq)`, `(xq, −xi)`, `(−xi, −xq)`, `(−xq, xi)` | Model + directed | [PLAN] |
| DER-QR-02 | Saturating negate: an input of −32768 negated gives +32767, on I and on Q, in each quadrant that negates it | Directed | [PLAN] |
| DER-PIPE-01 | Symbol and valid delayed exactly 1 clock; data change every symbol, with gaps | SVA + model | [PLAN] |

### 5.6 Complex multiplier

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-MUL-01 | Equations and truncation (floor) bit-exact vs model, including negative products | Model | [PART] (golden only) |
| DER-MUL-02 | Saturation to +32767 / −32768 on I and on Q, e.g. corner inputs I = Q = −32768 at 45° | Directed | [PLAN] (golden never saturates) |
| DER-MUL-03 | 2-clock latency, valid pipeline; products load only on valid; outputs hold otherwise | SVA | [PLAN] |

### 5.7 Datapath integration

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-DP-01 | Golden stream bit-exact: 1298 outputs | Scoreboard | [PART] (blocked by D-ENV-01 / 02) |
| DER-DP-02 | Total latency 3 for every valid pattern: back-to-back, 4-clock spacing, random gaps, single pulses | SVA `m_axis_valid_o == $past(s_axis_valid_i, 3)` after reset | [PART] (implication only) |
| DER-DP-03 | Rotation direction: with `fcw = 0`, `phase_adj = k·π/2`, a known symbol is rotated by −k·90° | Directed | [PLAN] |
| DER-DP-04 | CFO removal: input tone `A·e^(j2πfn)`, `coarse_word` = f, output has constant phase; residual stays within the quantization bound (phase step (π/2)/4096 ≈ 3.8·10⁻⁴ rad, so worst-case angle error about 2·10⁻⁴ rad, about −74 dB; confirm with the MATLAB model) | Directed + model | [PLAN] |
| DER-DP-05 | Closed loop with the Costas: residual frequency and phase converge | Block-level co-simulation, top plan TOP-DP-12 | [PLAN] |
| DER-DP-06 | Coarse word arrives before the first symbol (row 380 vs 385) and is already applied to it | Golden | [PART] |
| DER-DP-07 | Full-turn accumulation: 16384 symbols at `fcw = 2^18` return `phase_o` to its start | `t_lut_sweep` | [PLAN] |

### 5.8 Robustness

| ID | Feature | Method | Status |
|---|---|---|---|
| DER-ROB-01 | No X on valid-qualified outputs | SVA `a_known_out` | [DONE] |
| DER-ROB-02 | No X on `phase_o` / `freq_word_o` after reset; no X on control inputs | SVA | [PLAN] |
| DER-ROB-03 | Valid gaps (1 … 20 clocks) inside a stream: NCO and pipelines freeze and resume correctly | Directed | [PLAN] |
| DER-ROB-04 | Back-to-back valids (every clock) | Directed | [PLAN] |
| DER-ROB-05 | `freq_adj_valid_i` or `coarse_valid_i` on the same clock as a valid symbol (golden never does) | Directed | [PLAN] |
| DER-ROB-06 | Input extremes: −32768, −1, 0, 1, 32767 on I and Q, all quadrants | Directed | [PLAN] |
| DER-ROB-07 | Force override switched on and off during a stream | Directed | [PLAN] |
| DER-ROB-08 | Constrained-random stream vs reference model | `t_random_rm` | [PLAN] |

---

## 6. Test list

| Test / option | Stimulus | Checking | Status |
|---|---|---|---|
| `derotator_test` (default) | Golden replay, 10-clock drain | Scoreboard | [PART] (D-ENV-01 / 02 / 03) |
| `t_golden` | Fixed decoder; golden replay | Bit-exact on 1298 outputs, queue empty, comparisons > 0 | [PLAN] |
| `t_golden_x2` | Golden twice with a reset between | Both runs match | [PLAN] |
| `t_lut_sweep` | `coarse_word = 1024` (`fcw = 2^18`, one index per symbol), 16384 symbols, constant non-zero symbol | Every index in every quadrant; model compare; `phase_o` returns to start | [PLAN] |
| `t_rom_check` | Any stream | Tap: all 4096 entries and `cos = S[~a]` vs formula | [PLAN] |
| `t_quad_rot` | `fcw = 0`, `phase_adj` = 0 / 90 / 180 / 270°, symbols at all signs | Rotation direction and saturating negate | [PLAN] |
| `t_phase_adj` | Pulse held high, repeated, coincident and non-coincident with valid | One-shot semantics | [PLAN] |
| `t_freq_word` | Coarse, adj, force in every ordering and coincidence | `freq_word_o` formula | [PLAN] |
| `t_force` | Force on / off mid-stream | Priority and release | [PLAN] |
| `t_nco_wrap` | Large positive and negative `fcw` | Wrap, quadrant crossing | [PLAN] |
| `t_gaps` | Valid patterns: back-to-back, 1…20-clock gaps, single pulses | Latency 3, outputs vs model | [PLAN] |
| `t_extremes` | ±full-scale inputs, corner symbols | Both saturation paths, no X | [PLAN] |
| `t_cfo_tone` | Tone with CFO, matching coarse word, small adj | Residual phase error bound | [PLAN] |
| `t_reset_mid` | Reset during a stream | Clean restart | [PLAN] |
| `t_random_rm` | Constrained-random stimulus | Full scoreboard vs model | [PLAN] |

Regression: golden, golden ×2, then each directed test with its own seed; merge UCDBs before reading closure numbers.

---

## 7. Checkers

### 7.1 Scoreboard (to be rebuilt)

An SV reference model, bit-exact, driven by the stimulus the driver publishes. One step per clock, from the RTL (the Python model of 3.3 follows this and reproduces the golden):

```
coarse_now  = coarse_valid ? (coarse_word << 8) : coarse_reg
adj_used    = freq_adj_valid ? freq_adj : adj_reg
freq_word'  = force_en ? force_freq : (coarse_now + adj_used)          // 32-bit wrap
(q, a)      = (phase[31:30], phase[29:18])
x'          = x · (−j)^q    with neg(−32768) = +32767
phase'      = phase + (valid ? freq_word : 0) + (rising_edge(phase_adj_valid) ? phase_adj : 0)
rom regs    ← on valid: s0 = S[a], c0 = S[~a]; pipeline regs ← x'
y_re = sat16((x'_re·c0 + x'_im·s0) >>> 15)      // truncation, not rounding
y_im = sat16((x'_im·c0 − x'_re·s0) >>> 15)
```

| Check | Severity |
|---|---|
| Each valid output equals the model, in order | `uvm_error` |
| `m_axis_valid_o` is high exactly 3 clocks after `s_axis_valid_i` | `uvm_error` |
| `phase_o` and `freq_word_o` equal the model every clock (after reset) | `uvm_error` |
| Missing or extra outputs (leftover / extra counters) | FAIL in `report_phase` |
| PASS rule | PASS only if comparisons > 0, no mismatch, no extra, no leftover |

For the golden stream the 1299th output (R2) must be expected or explicitly tolerated.

### 7.2 SVA

Existing: `a_known_out`, `a_valid_origin`.

Planned: latency equality (3 clocks, after reset); reset values (DER-RST-01); `freq_word_o` formula and force priority; `phase_o` holds when there is no valid symbol and no `phase_adj` pulse; `phase_o` increment on a valid symbol; `phase_adj` rising-edge one-shot; ROM output range 0 … 0x7FFF and registered read; output data stable while valid is low; no X on observation outputs.

---

## 8. Coverage plan

### 8.1 Functional coverage

The current covergroups only record that signals toggled and are mis-sampled (D-ENV-04). Replace them with:

| Item | Bins | Purpose |
|---|---|---|
| `cp_valid` | 0/1; transitions; gap length 1, 2, 3, 4, 5–20; run of back-to-back valids ≥ 8 | Valid patterns |
| `cp_nco_quad × cp_in_quad` | 4 × 4 at the symbol's input cycle | Every rotation case |
| `cp_lut_idx` | 16 uniform bins plus 0, 1, 4094, 4095 | Table index range |
| `cp_coarse` | negative, zero, positive, extremes | Coarse word |
| `cp_adj` | negative, zero, positive, large | Costas correction |
| `cp_force` | off / on; 0→1, 1→0; × valid | DFT override |
| `cp_padj` | value 0, 90, 180, 270°, other × coincident with valid × held ≥ 2 clocks × two pulses with gap | One-shot behaviour |
| `cp_neg_sat` | input −32768 on I, on Q, per quadrant that negates it | Saturating negate |
| `cp_mul_sat` | output saturated high / low on I and Q | Multiplier saturation |
| `cp_coincide` | coarse + adj; coarse + symbol; adj + symbol | Control coincidences |
| `cp_fw_wrap` | positive and negative overflow of coarse + adj | 32-bit wrap |
| `cp_phase_wrap` | accumulator crossing 2^32 | NCO wrap |
| `cp_in_extreme` | I and Q in {−32768, −1, 0, 1, 32767} | Corner inputs |

### 8.2 Code coverage

The supplied report is from an older build and a mis-decoded stimulus (D-ENV-01, D-ENV-06). It is kept here only as a baseline.

| Instance | Stmt | Branch | Cond | Expr | Toggle |
|---|---|---|---|---|---|
| `freq_word_inst` | 93.3 | 84.6 | – | – | 54.4 |
| `nco_inst` | 100 | 75.0 | – | 0 | 18.6 |
| `lut_rom_inst` | 0.07 (3 / 4104) | 0.02 (1 / 4099) | – | – | 1.3 |
| `quadrant_rotator_inst` | 60.0 | 50.0 | 0 | – | 43.9 |
| `input_pipeline_inst` | 66.7 | 75.0 | – | – | 25.7 |
| `complex_multiplier_inst` | 41.2 | 44.4 | 0 | – | 0.65 |
| `derotator` (top) | – | – | – | – | 34.2 |

Total (filtered view): 5.80 %. Assertions: 0 / 3, with 897 failures of the old `a_force_freq`.

Targets: statement ≥ 95 %, branch ≥ 90 %, condition / expression ≥ 85 %, toggle ≥ 80 % with documented waivers. The ROM is a 4096-item case statement, so statement and branch closure needs every index addressed (`t_lut_sweep`); the sweep also provides the quadrant coverage. Toggle waivers expected for constant upper bits of `fcw` in the golden-only runs.

### 8.3 Assertion coverage

100 % of assertions attempted at least once, 0 failures, all cover properties hit, no vacuous passes.

---

## 9. Assumptions and known limitations

1. Outputs are paired with expectations **by order**, not by cycle; the latency is checked separately by SVA.
2. The golden vector covers one scenario: a single coarse word, 4-clock spacing, one `phase_adj` pulse, no force override, no saturation. Everything else relies on the reference model (7.1).
3. The reference model is derived from the RTL, so it cannot catch a misreading shared by the RTL and the model. The golden vector is the independent reference (the model reproduces it bit-exactly, 3.3); `DER-DP-03` and `DER-DP-04` check the physics (direction, CFO removal) independently of the model.
4. The 4096-entry table is checked against the closed-form formula, not against the MATLAB export directly; the two agree on all entries.
5. `Phase_Bits ≠ 12` or `DataWidth ≠ 16` is unsupported by the ROM.
6. Datapath registers have no reset; checks are valid-qualified.

---

## 10. Running

```
cd derotator_uvm
vsim -do run.do      # vlib, vlog -f src_files.list +cover -covercells, vsim -cover,
                     # run -all, vcover report -details -all -> coverage_rpt_derotator.txt
```

`tb_derot_vec.hex` must be in the simulation directory. `src_files.list` references `freq_word.sv`; the file in the folder is named `Freq_word.sv`, which fails on a case-sensitive file system. Planned plusargs: `+TEST=<name>`, `+SEED=<n>`.

---

## 11. Exit criteria

- Golden test PASS with **comparisons > 0**: 1298 / 1298 outputs match, queue empty, the extra output (R2) explained.
- Every `DER-*` item is implemented and passing, or closed with a written justification.
- All SVA pass, none vacuous.
- Functional coverage 100 % with justified exclusions; code-coverage targets of 8.2 met on the merged database, including all 4096 ROM indices.
- Report regenerated on the current sources.

---

## 12. Risks and open items

| # | Item | Impact | Action |
|---|---|---|---|
| R1 | RTL comments say "round half up"; code and golden use truncation | Misleading documentation; a reviewer could "fix" the RTL | Correct the header of `complex_multiplier.sv` and `derotator.md`; confirm the MATLAB model truncates |
| R2 | 1299 valid inputs, 1298 expected outputs | Scoreboard cannot pair the last output | Decide: golden truncated, or model drops the last symbol |
| R3 | Coarse word in the vector is 1093103; `expected_metrics.txt` says `coarse_cfo_stored = 1089400` | Different definitions of the stored value | Confirm which is authoritative (difference is inside the ±5000 tolerance used in the sub-UVMs) |
| R4 | `phase_adj = 0x80000000` (k = 2) vs `quad_k = 1` in the metrics file | Convention mismatch | See Costas plan COS-QD-11 |
| R5 | `derotator.md` is referenced by the RTL header but is not in the delivered folder | Specification not available for review | Provide the file |
| R6 | The golden never exercises force, saturation, coincident control pulses, or gaps | Escapes | Section 6 tests |
| R7 | `phase_adj_valid_i` must fall between two corrections (RTL requirement) | A producer that holds it high loses the second correction | Add an assertion in the top-level wrapper; Costas produces a one-clock pulse |
| R8 | Environment defects D-ENV-01 … 03 | A "pass" may check nothing | Fix first; non-vacuity rule |
| R9 | `src_files.list` case mismatch (`freq_word.sv` / `Freq_word.sv`) | Compile failure on Linux | Rename or fix the list |
