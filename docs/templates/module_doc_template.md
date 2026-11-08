# <Module name>

Source of truth: the golden model function(s) `<file.m>`.

> Copy this file to `docs/modules/<module>.md` and replace every `<...>`.
> Keep it short: tables and equations rather than prose, and link to other documents instead of repeating them.
> Write **TBD** for anything not decided yet. Never invent a number. State where each value comes from.
> Delete the guidance lines (starting with `>`) in the finished document.

## 1. Overview

> What the module does, in two or three sentences, and where it sits in the chain.

```
<block diagram: inputs -> blocks -> outputs>
```

> Spec requirements it must meet (ID and value), for example `R.111 jitter <= 0.02 Ts RMS at SNR 15 dB`.

## 2. Interface

> Data ports are valid streams with separate I and Q ports and no `ready` (see `CODING_STANDARDS.md`, section 3).
> Control, status and DFT ports are plain signals with `_i` / `_o` suffixes.

| Port | Dir | Width / format | Description |
|---|---|---|---|
| `clk_i` | in | 1 | Clock |
| `rst_ni` | in | 1 | Active-low reset |
| `s_axis_valid_i` | in | 1 | |
| `s_axis_i_sym_i` | in | | |
| `s_axis_q_sym_i` | in | | |
| `m_axis_valid_o` | out | 1 | |
| `m_axis_i_sym_o` | out | | |
| `m_axis_q_sym_o` | out | | |

**Parameters**

| Name | Default | Meaning |
|---|---|---|
| | | |

**Protocol and timing.** > Valid/strobe behaviour, when outputs are valid, and a timing diagram if useful.

**Reset.** > Reset value of every register that matters.

**Latency.** > Cycles from input to output. State whether it is fixed.

## 3. How it works

> Algorithm and equations.

> Architecture: datapath, control, registers and pipeline stages. For every state register, mark `SATURATING` or `WRAPPING`.

> Fixed-point details: widths, scaling, rounding mode, overflow handling.

> The golden-model function this block must match, and the fields it logs.

## 4. FSM

> Write **None** if the module has no state machine.

![state diagram](../figures/<module>_fsm.png)

**States**

| State | Encoding | Meaning | Active outputs |
|---|---|---|---|
| | | | |

**Transitions**

| From | To | Condition (exact signals and thresholds) | Priority |
|---|---|---|---|
| | | | |

**Outputs per state.** > Moore or Mealy, and the output table.

**Reset state and timing.** > Reset state, typical and worst-case time in each state.

**Illegal states.** > What happens in unused encodings, and how a timeout recovers.

## 5. Configuration constants

| Constant | Value | Source |
|---|---|---|
| | | `<golden model file or run>` |

## 6. Verification plan

> Filled in later. One row per requirement or feature.

| ID | Requirement (spec ref) | Feature | Test or checker | Stimulus file | Pass criterion |
|---|---|---|---|---|---|
| | | | | | |

**Coverage.** > Coverage points and goals, filled in later.

## 7. Open issues and decisions

> Open questions, interim choices, and decisions waiting for the team or the organisers. Remove an item once it is decided
> and move the decision to the section it belongs to.

| # | Issue | Interim choice | Owner |
|---|---|---|---|
| | | | |
