# Verification Plan — Top Wrapper (`sync_system_top`)

**Project:** Real-Time All-Digital Carrier & Timing Synchronization Unit (ERI – SI_CLASH)
**DUT:** `sync_system_top` = STR → Coarse CFO → Derotator → Costas loop, plus `burst_ctrl`, `err_align`, `dft_mux`
**Environment:** UVM, folder `sync_system_top_uvm/`
**Status legend:** `[DONE]` implemented in the delivered environment · `[PART]` partially implemented · `[PLAN]` planned, not yet implemented

> The environment was delivered **without a simulator run** (none was available when it was written). Every `[DONE]` below means "coded and structurally reviewed", not "passing". The first regression is the first real evidence.

---

## 1. Scope and goals

1. Prove the integrated chain produces the golden output symbols for the reference burst (190-symbol preamble + 1200-symbol payload, 16-QAM).
2. Prove the burst control FSM sequences correctly: acquire → coarse estimate → load → Costas acquire → track → watchdog flush → soft reset.
3. Prove the integration glue is right: `flush` repeat-pad, derotator gating, 10-stage `mod_type` delay, forced-QPSK slicer during acquisition, `fine_cfo_est` composition, `lock_detect`, error alignment, DFT mux, force overrides.
4. Prove robustness: back-to-back bursts, gaps, reset mid-burst, X-freedom.
5. Reach the coverage closure targets in section 8.

**Out of scope (covered in the subsystem plans):** internal correctness of the interpolator, TED, PI loops, CORDIC, NCO/ROM, slicer, phase error, quadrant check. The top plan only re-checks them through their observable effect on the system output.

---

## 2. DUT overview

### 2.1 Data and control flow

```
in_sample (12b, 4 samples/symbol)
   │   flush_active ? last_sample : in_sample        (repeat-pad during FLUSH)
   ▼
 str_top ──str_valid/str_sym──► coarse_cfo_core ──coarse_est──┐
   │  lock, ted_err, mu, w                                    ▼
   └──str_sym (gated: str_valid & fsm_state>=4)──► derotator ◄── costas freq_adj / phase_adj
                                                     │
                                       derot_sym ──► costas_top (mod_type delayed 10 clk,
                                                     │           mode from burst_ctrl,
                                                     │           slicer_qpsk = (state != Track))
                                                     ▼
                                   out_sym_i/q/valid, lock_detect = str_lock & costas_lock
 burst_ctrl: WaitBurst→Acquire→CoarseEst→Load→CostasAcq→Track→Flush
 err_align : aligns TED error (2 clk) and Costas error (0 clk)  → DFT bus
 dft_mux   : 16 x 32-bit observation channels → dft_obs_data
```

### 2.2 Key parameters (RTL defaults)

| Parameter | Value | Meaning |
|---|---|---|
| `NA1` / `NA2` / `NPreamble` | 70 / 40 / 190 | STR acquire, coarse estimate, total preamble (symbols) |
| `IDLE_TIMEOUT` / `FLUSH_CLOCKS` | 14 / 16 | Watchdog invalid-clock count / pipeline drain clocks |
| `CoarseWidth` / `PhaseWidth` / `MuWidth` | 24 / 32 / 10 | 2^24 and 2^32 = one turn |
| `ModQpsk` / `ModQam16` | 2'b00 / 2'b01 | Encoding "TBD with organizers" per RTL comment |
| `TedErrAlign` / `CostasErrAlign` | 2 / 0 | "TBD by simulation" per RTL comment |

### 2.3 Burst FSM (from `burst_ctrl.sv`)

| State | Code | Leaves when |
|---|---|---|
| WaitBurst | 0 | `start_of_burst` or `in_sample_valid` → Acquire |
| Acquire | 1 | NA1 symbols counted **or** `str_lock` → CoarseEst |
| CoarseEst | 2 | `coarse_valid` (+strobe → CostasAcq, else Load); or NA1+NA2 symbols → Load |
| Load | 3 | next symbol strobe → CostasAcq |
| CostasAcq | 4 | NPreamble symbols → Track (`preamble_end`, delayed 4 clk) |
| Track | 5 | idle watchdog |
| Flush | 6 | 16 clocks → WaitBurst + 1-clk soft reset (`flush_rst`) |

Watchdog: 14 consecutive `in_sample_valid = 0` clocks in states 1–5 force Flush.

---

## 3. Reference data

| File | Content |
|---|---|
| `tb_top_vec.hex` | 5624 lines, one per clock: `valid_i_q_sob_expvalid_expI_expQ_state_explock` (19 hex digits) |
| `expected_metrics.txt` | N_preamble 190, N_payload 1200, mod_type 1, **coarse_cfo_stored 1089400**, str_lock_sym 54, costas_lock_sym 189, quad_k 1, quad_unresolved 0, excess EVM 3.4219 %, total EVM 7.1641 %, SER 0 |
| `expected_out_i/q.hex` | 1390 symbols (190 preamble + 1200 payload) |
| `expected_ideal_i/q.hex` | 1200 ideal payload constellation points |

Facts measured from `tb_top_vec.hex`:

- 5560 valid input samples (= 1390 symbols × 4) followed by 64 idle cycles.
- 1298 `exp_valid` strobes (output symbols emitted once the FSM reaches CostasAcq).
- FSM state per line: 1 from line 0, 2 at 234, 3 at 380, 4 at 381, 5 at 765, 6 at 5573, 0 at 5591. The golden run therefore takes the Acquire → CoarseEst transition early (consistent with `str_lock_sym = 54 < NA1 = 70`) and passes through the one-cycle Load state.
- Only 1 line has `start_of_burst = 1` (line 0).

---

## 4. Environment architecture

| Component | File | Role |
|---|---|---|
| Interface | `sync_system_top_interface.sv` | All DUT ports + 5 internal taps (`fsm_state`, `str_lock`, `costas_lock`, `coarse_valid`, `str_valid`) |
| Item | `sync_system_top_seq_item.sv` | Inputs, golden expectations, sampled outputs |
| Sequences | `reset_seq.sv`, `golden_seq.sv`, `main_seq.sv` | Reset, golden-vector replay, directed smoke/DFT/force |
| Driver | `sync_system_top_driver.sv` | Drives at negedge; publishes expected symbols and expected FSM state *changes* |
| Monitor | `sync_system_top_monitor.sv` | Samples every cycle at negedge (inputs, outputs, taps) |
| Scoreboard | `sync_system_top_scoreboard.sv` | Symbol, FSM-sequence, coarse-CFO and lock checks |
| Coverage | `sync_system_top_coverage.sv` | Functional covergroup `g1` |
| SVA | `sva.sv` (bound into `sync_system_top`) | Protocol/integration assertions |
| Top | `sync_system_top_top.sv` | 125 MHz clock, DUT, taps, bind |

Design decisions:

- **Order-based symbol compare**, not cycle-based. Latency changes do not break the check.
- **State sequence compare**, not cycle-accurate state compare, for the same reason.
- Items from `golden_seq` carry `golden = 1`, so unchecked sequences (`+SEQ=main`) never feed the checkers.

---

## 5. Feature list and traceability

### 5.1 Burst control (`burst_ctrl`)

| ID | Feature | Method | Status |
|---|---|---|---|
| TOP-FSM-01 | Reset forces WaitBurst | SVA `a_reset_state` | [DONE] |
| TOP-FSM-02 | Only legal states 0–6 | SVA `a_legal_state`, `cp_state` illegal bin | [DONE] |
| TOP-FSM-03 | Golden state sequence 0→1→2→3→4→5→6→0 | Scoreboard state-change compare | [DONE] |
| TOP-FSM-04 | WaitBurst only left on `start_of_burst` or valid sample | SVA `a_start` | [DONE] |
| TOP-FSM-05 | Early path Acquire → CoarseEst on `str_lock` | Golden run (lock at symbol 54) | [DONE] (implicit) |
| TOP-FSM-06 | Timeout path Acquire → CoarseEst at NA1 = 70 without lock | Needs a vector with delayed lock | [PLAN] |
| TOP-FSM-07 | CoarseEst → CostasAcq direct (valid coincides with strobe) vs via Load | Golden run takes Load; direct path needs a second vector/directed test | [PART] |
| TOP-FSM-08 | CoarseEst timeout at NA1+NA2 = 110 | Force `coarse_valid` never to occur (e.g. stall) | [PLAN] |
| TOP-FSM-09 | CostasAcq → Track at 190 symbols; `preamble_end` 4 clk later | Golden state sequence; SVA on `preamble_end` timing | [PART] |
| TOP-FSM-10 | Idle watchdog: 14 invalid clocks → Flush | SVA `a_watchdog` + tail of golden vector (64 idle) | [DONE] |
| TOP-FSM-11 | Gap of 13 invalid clocks does **not** flush | Directed gap test | [PLAN] |
| TOP-FSM-12 | Flush lasts 16 clocks, then soft reset pulse, FSM returns to WaitBurst | Golden tail + SVA on flush length | [PART] |
| TOP-FSM-13 | `valid_during_flush` counts valid samples arriving in Flush | Directed test + SVA | [PLAN] |
| TOP-FSM-14 | Second burst accepted after Flush | `main_seq` runs two bursts (unchecked) | [PART] |

### 5.2 Datapath integration

| ID | Feature | Method | Status |
|---|---|---|---|
| TOP-DP-01 | Output symbols = golden (I and Q, bit exact) | Scoreboard, in order | [DONE] |
| TOP-DP-02 | No missing and no extra output symbols | `leftover` + `extra_count` | [DONE] |
| TOP-DP-03 | `out_sym_valid` only from CostasAcq onwards (derotator gated by `fsm_state >= 4`) | SVA `a_out_after_acq` | [DONE] |
| TOP-DP-04 | Coarse CFO within tolerance of 1089400 when FSM enters CostasAcq | Scoreboard (±5000, same as sub-UVM) | [DONE] |
| TOP-DP-05 | Flush repeat-pad: during Flush the STR sees the last valid sample | Compare STR input in Flush against last valid sample (tap) | [PLAN] |
| TOP-DP-06 | `mod_type` reaches Costas delayed by 10 clocks (matches STR + derotator latency) | Tap on `mod_type_pipe[9]`; test with mod_type change | [PLAN] |
| TOP-DP-07 | `slicer_qpsk` forced to 1 until Track, then follows modulation | Tap + SVA (`slicer_qpsk == (fsm_state != 5)`) | [PLAN] |
| TOP-DP-08 | `fine_cfo_est = coarse<<8 + costas_int` | Tap + SVA/scoreboard arithmetic check | [PLAN] |
| TOP-DP-09 | `coarse_cfo_est` held after estimate, cleared by soft reset | Check around Flush | [PLAN] |
| TOP-DP-10 | `lock_detect = str_lock & costas_lock` | SVA `a_lock_and` | [DONE] |
| TOP-DP-11 | Lock timing vs golden (`str_lock_sym`, `costas_lock_sym`) | `exp_lock` per symbol (informational); lock-symbol-index check | [PART] |
| TOP-DP-12 | Costas feedback closes the loop (freq_adj/phase_adj reach derotator) | Implicit in TOP-DP-01; explicit tap check | [PLAN] |
| TOP-DP-13 | Quadrant ambiguity resolved (`quad_k = 1`, `quad_unresolved = 0`) | Tap on `costas_quad_unres` at end of preamble | [PLAN] |

### 5.3 System-level quality metrics

| ID | Metric | Golden value | Method | Status |
|---|---|---|---|---|
| TOP-MET-01 | Symbol error rate over payload | 0 | Slice 1200 payload outputs against `expected_ideal_*` | [PLAN] |
| TOP-MET-02 | Excess EVM | 3.4219 % | Accumulate EVM in scoreboard, tolerance TBD | [PLAN] |
| TOP-MET-03 | Total EVM | 7.1641 % | Same | [PLAN] |

Bit-exact match to `expected_out_*` already implies the metrics; TOP-MET checks matter when the DUT is later compared against a *non-bit-exact* model or run on different stimulus.

### 5.4 Observability, DFT, overrides

| ID | Feature | Method | Status |
|---|---|---|---|
| TOP-DFT-01 | `dft_sel` 0–15 each selects the documented channel | Compare `dft_obs_data` with the matching internal tap per channel | [PLAN] |
| TOP-DFT-02 | `dft_sel` sweep exercised | `main_seq` sweeps `dft_sel`; `cp_dft_sel` | [DONE] (stimulus + coverage only) |
| TOP-DFT-03 | `force_w_en/force_w` overrides STR loop word | `main_seq` burst 2; check `w_o` tap == force value | [PART] |
| TOP-DFT-04 | `force_cfo_en/force_cfo` overrides coarse estimate | `main_seq` burst 2; check `coarse_cfo_est` | [PART] |
| TOP-DFT-05 | `force_freq_en/force_freq` overrides NCO frequency word | `main_seq` burst 2; check `freq_word` tap | [PART] |
| TOP-DFT-06 | Error alignment delays (2 / 0) correct | Compare `ted_err` vs aligned bus delay | [PLAN] |
| TOP-DFT-07 | `loop_gain` / `costas_loop_gain` (RTL: "currently unused") | Confirm no effect; revisit when used | [PLAN] |

### 5.5 Robustness

| ID | Feature | Method | Status |
|---|---|---|---|
| TOP-ROB-01 | No X on outputs when valid | SVA `a_no_x_out` | [DONE] |
| TOP-ROB-02 | No X on control inputs | SVA `a_no_x_in` | [DONE] |
| TOP-ROB-03 | Reset in the middle of a burst, then a clean burst | Directed test | [PLAN] |
| TOP-ROB-04 | Back-to-back bursts, golden-checked | Golden vector twice in one run | [PLAN] |
| TOP-ROB-05 | `start_of_burst` with `in_sample_valid = 0` | Directed test | [PLAN] |
| TOP-ROB-06 | Input saturation values (±2047) | Directed test | [PLAN] |
| TOP-ROB-07 | Valid de-asserted for several clocks inside a burst (< 14) | Directed gap test; STR freezes when `ce_str = 0` | [PLAN] |

---

## 6. Test list

| Test / option | Stimulus | Checking | Status |
|---|---|---|---|
| `sync_system_top_test` (default) | reset → `golden_seq` (16-QAM) → 40-clk drain | Full scoreboard | [DONE] |
| `+SEQ=main` | reset → `sync_main_seq` (2 bursts, DFT sweep, force windows, idle gaps) | SVA + coverage only (scoreboard disabled) | [DONE] |
| `+MOD_TYPE=0` | golden file replayed as QPSK | Not meaningful: vectors were generated for 16-QAM | [PLAN] (needs QPSK vectors) |
| `+CHECK_LOCK` | golden run | Makes `lock_detect` vs golden an error | [DONE] |
| `+NO_CFO_CHECK`, `+EXP_CFO`, `+CFO_TOL` | golden run | CFO check controls | [DONE] |
| `t_gap_13` / `t_gap_14` | golden prefix, then 13 / 14 idle clocks mid-burst | No flush / flush | [PLAN] |
| `t_reset_mid_burst` | assert `rst_n` during Track, restart | Clean second burst vs golden | [PLAN] |
| `t_back_to_back` | golden vector twice with idle in between | Both bursts match golden | [PLAN] |
| `t_flush_valid` | valid samples during Flush | `valid_during_flush` count | [PLAN] |
| `t_dft_check` | sweep `dft_sel` while stimulus runs | Channel == tap | [PLAN] |
| `t_force_*` | force each override with known values | Output/tap equals forced value | [PLAN] |
| `t_cfo_sweep`, `t_timing_sweep`, `t_snr_sweep` | New vectors from the MATLAB model | Golden compare + metrics | [PLAN] (needs vector generator) |

---

## 7. Checkers

### 7.1 Scoreboard (`sync_system_top_scoreboard.sv`)

| Check | Severity | Notes |
|---|---|---|
| Output I/Q equals next golden symbol | `uvm_error` `SB_MISMATCH` | In order; first 20 printed |
| Output with empty golden queue | `uvm_error` `SB_EXTRA` | |
| Golden symbols never produced | FAIL in `report_phase` | `leftover` |
| FSM state-change sequence equals golden | `uvm_error` `SB_STATE` | Also flags extra and missing transitions |
| Coarse CFO within ±`cfo_tolerance` of `exp_coarse_cfo` at entry to CostasAcq | `uvm_error` `SB_CFO` | Default 1089400 ± 5000 |
| `lock_detect` vs golden `exp_lock` per symbol | Info; error with `+CHECK_LOCK` | Mirrors the STR scoreboard policy |
| PASS rule | PASS only if no mismatches, no extras, nothing left over, state sequence clean, CFO clean, and at least one symbol matched | |

### 7.2 SVA (`sva.sv`)

`a_reset_state`, `a_legal_state`, `a_flush_state`, `a_lock_and`, `a_no_x_out`, `a_no_x_in`, `a_out_after_acq`, `a_watchdog`, `a_start`; covers `c_full_burst`, `c_lock`, `c_out_valid`.

Planned additions: `slicer_qpsk` rule, `preamble_end` 4-clock delay, flush length 16, `fine_cfo_est` arithmetic, `valid_during_flush` increments, `flush_rst` one-cycle pulse.

---

## 8. Coverage plan

### 8.1 Functional coverage (`g1`)

| Item | Bins | Purpose |
|---|---|---|
| `cp_state` | 7 states + illegal | Every FSM state visited |
| `cp_state_trans` | full burst chain, early-lock (1→2), coarse direct (2→4), watchdog (1..5→6) | Path coverage |
| `cp_mod_type` | QPSK, 16-QAM | Both modulations |
| `cp_out_valid`, `cp_in_valid`, `cp_sob`, `cp_flush` | 0/1 | Handshake activity |
| `cp_lock`, `cp_str_lock`, `cp_cos_lock` | 0/1 | Lock behavior |
| `cp_dft_sel` | 16 values | Every DFT channel |
| `cp_force_w/cfo/frq` | 0/1 | Every override |
| `cp_cfo_sign` | positive / negative (state ≥ 4) | CFO polarity |
| Crosses | state×out_valid, state×lock, mod×state, dft×state | Interaction |

Reachability note: the golden run alone covers 16-QAM only, positive CFO only, one transition path, and no force/DFT activity. Reaching 100 % **requires** `+SEQ=main` plus the planned tests (QPSK vectors, negative CFO vector, timeout-path vectors). Bins that stay unreachable by design must be excluded with a written justification, not silently ignored.

### 8.2 Code coverage targets (DUT + glue)

| Metric | Target |
|---|---|
| Statement | ≥ 95 % |
| Branch | ≥ 90 % |
| Condition / expression | ≥ 85 % |
| FSM (`burst_ctrl`) | 100 % states, ≥ 90 % transitions |
| Toggle | ≥ 80 % overall, waivers documented (e.g. unused high bits) |

### 8.3 Assertion coverage

100 % of assertions attempted at least once; 0 failures; all cover properties hit.

---

## 9. Assumptions and known limitations

1. Pairing of outputs with expectations is **by order**. A DUT that drops one symbol and later shifts alignment is caught by `leftover`/`extra`, not by a per-cycle compare.
2. `lock_detect` is informational by default, like the STR sub-UVM, because the golden `exp_lock` is aligned to input timing, not output timing.
3. The CFO check assumes `coarse_cfo_stored` equals the 24-bit `coarse_cfo_est` held when the FSM enters CostasAcq, and uses the sub-UVM tolerance (±5000). If this assumption is wrong, expect `SB_CFO` errors and change `+EXP_CFO` / `+CFO_TOL` or disable with `+NO_CFO_CHECK`.
4. Internal taps are read through hierarchical references in `sync_system_top_top.sv`; they are observation-only.
5. Hex vectors are for one scenario (16-QAM, one CFO, one timing offset). Robustness against other conditions needs new vectors from the reference model.
6. `ModQpsk/ModQam16`, `CostasHold/Acq/Track` encodings and `TedErrAlign` are marked "TBD" in the RTL; tests must be re-run when organizers confirm.

---

## 10. Running

```
cd sync_system_top_uvm
vsim -do run.do                                  # golden test (default)
vsim -c -do "..." +SEQ=main                      # directed smoke / DFT / force
+MOD_TYPE=<0|1>  +EXP_CFO=<n>  +CFO_TOL=<n>  +NO_CFO_CHECK  +CHECK_LOCK  +VEC_FILE=<path>
```

`run.do` compiles `src_files.list`, runs with coverage and saves `sync_system_top_tb.ucdb`. `tb_top_vec.hex` must be in the simulation directory (or pass `+VEC_FILE`).

Regression: golden, `+SEQ=main`, then each planned directed test with its own seed; merge UCDBs before reading closure numbers.

---

## 11. Exit criteria

- Golden test PASSED: 0 mismatches, 0 extras, 0 leftover, state sequence clean, CFO within tolerance.
- All SVA pass, none vacuous.
- Functional coverage 100 % (with justified exclusions) and code-coverage targets of section 8.2 met on the merged database.
- Every `[PLAN]` item is either implemented and passing, or closed with a written justification.
- All lock-timing discrepancies explained (golden vs RTL), not just waived.

---

## 12. Risks and open items

| # | Item | Impact | Action |
|---|---|---|---|
| 1 | No simulator run yet | Unknown compile/runtime issues | Run first regression; fix |
| 2 | Single golden scenario | Escapes in other CFO/timing/SNR conditions | Generate more vectors |
| 3 | Error-alignment lengths TBD | DFT channels 0 and 5 may be misaligned | Confirm with organizers, then TOP-DFT-06 |
| 4 | Modulation / mode encodings TBD | Mis-decode if encodings change | Re-run on update |
| 5 | CFO golden definition | False failures or false passes | Confirm `coarse_cfo_stored` meaning |
| 6 | `loop_gain` unused | Gain changes cannot be verified | Re-plan when wired |
