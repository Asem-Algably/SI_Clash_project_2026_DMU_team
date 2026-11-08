# Coding Standards

These rules apply to every RTL and testbench file in this repository. They follow the
[lowRISC Verilog coding style guide](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md)
and the [Vivado synthesis guide (UG901)](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/).
Only the rules that matter most for this project are listed. For anything not covered here,
follow the lowRISC guide.

Each rule is tagged **[lowRISC]** (taken from that guide), **[UG901]** (from the Vivado guide)
or **[Project]** (specific to this repository). A deviation from any rule needs a comment
explaining why, and a lint waiver if the linter complains.

## 1. Files and layout

**One module per file. The file name matches the module name. Use `.sv` for modules and packages.** [lowRISC]

Lines are at most 100 characters. Use two spaces per indent level, no tabs, no trailing spaces,
and end each file with a newline.

Do:

```systemverilog
// File: coarse_cfo_acc.sv
module coarse_cfo_acc (
  input  logic clk_i,
  input  logic rst_ni
);
  // ...
endmodule
```

Don't:

```systemverilog
// File: acc.sv   (name differs from module, and two modules in one file)
module coarse_cfo_acc (input logic clk_i);
endmodule
module helper (input logic clk_i);
endmodule
```

**Design files go in `code/rtl/<module>/`, testbench files in `code/tb/<module>/`.** [Project]
Shared types, widths and constants live in `code/rtl/pkg/` and are compiled first.

## 2. Naming

**Use `lower_snake_case` for modules, signals, instances and functions. Use `UpperCamelCase` for parameters
and FSM state names. Use `ALL_CAPS` for macros.** [lowRISC]

**Use these suffixes.** [lowRISC]

| Suffix | Meaning |
|---|---|
| `_i`, `_o`, `_io` | Module input, output, inout port |
| `_n` | Active low (put before the direction suffix, for example `rst_ni`) |
| `_d`, `_q` | Register input (next value) and output (current value) |
| `_q2`, `_q3` | Further pipeline stages of the same signal |
| `_e`, `_t` | Enum type, other typedef |

The main clock is `clk_i` and the reset is `rst_ni` (active-low).

**Exception to the suffix rule.** [Project] Top-level ports keep the names given by the spec (`in_sample_i`, `out_sym_valid`,
`rst_n`, and so on). Do not rename them. Every other port follows the suffix rule, including the stream ports (section 3).

Do:

```systemverilog
logic signed [15:0] ted_err_d, ted_err_q;
logic               strobe_q, strobe_q2;
typedef enum logic [1:0] {Idle, Acquire, Track} burst_state_e;
parameter int unsigned MuWidth = 10;
```

Don't:

```systemverilog
logic signed [15:0] TedErr, tederr_reg;     // wrong case, wrong suffix
logic               strobe_1, strobe_2;     // pipeline stages use _q, _q2
typedef enum logic [1:0] {IDLE, ACQUIRE, TRACK} burst_state;   // missing _e
parameter int unsigned MU_WIDTH = 10;       // parameters are UpperCamelCase
```

**Fixed-point types are named `fx_q<I>_<F>_t`.** [Project] The `fx_` prefix avoids confusion with the
`_q` register suffix. Declare them once in `code/rtl/pkg/`.

Do:

```systemverilog
typedef logic signed [11:0] fx_q1_11_t;   // input sample, signed Q1.11
typedef logic signed [15:0] fx_q1_15_t;   // output symbol, signed Q1.15
```

Don't:

```systemverilog
logic signed [11:0] sample_q1_11_q;       // reads as a register called "sample_q1_11"
```

## 3. Declarations and instantiation

**Declare every signal before use. Use `logic` for design signals. Never rely on implicit nets.** [lowRISC]

**Module ports use the Verilog-2001 combined style. The clock comes first, then the reset, then the rest.** [lowRISC]

Do:

```systemverilog
module costas_pi (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic               err_valid_i,
  input  logic signed [15:0] err_i,
  output logic signed [31:0] freq_word_o
);
```

Don't:

```systemverilog
module costas_pi (err_i, clk_i, freq_word_o);   // old style, no types, order wrong
  input err_i; input clk_i;
  output [31:0] freq_word_o;
```

**Instantiate with named port connections for every port, in definition order. Do not use `.*` or
positional connections. Leave unused outputs as `.port()`.** [lowRISC]

Do:

```systemverilog
costas_pi u_costas_pi (
  .clk_i       (clk_i),
  .rst_ni      (rst_ni),
  .err_valid_i (err_valid),
  .err_i       (err),
  .freq_word_o (freq_word)
);
```

Don't:

```systemverilog
costas_pi u_costas_pi (.*);                          // implicit connections
costas_pi u_costas_pi (clk_i, rst_ni, v, e, f);      // positional
```

**Data between modules uses valid signals, with no ready.** [Project] The names follow AXI4-Stream, with the usual direction suffix.

- Port names: `s_axis_<name>` for inputs and `m_axis_<name>` for outputs, plus `_i` / `_o`:
  `s_axis_valid_i`, `s_axis_i_sym_i`, `m_axis_valid_o`, `m_axis_i_sym_o`.
- One port per value, with a meaningful name. I and Q are separate ports (`i_sym` / `q_sym`; `i_sample` / `q_sample` for raw input
  samples). There is no packed `tdata`. The format of each port is stated in the port table of the module document.
- **There is no `ready` anywhere.** Every module is always ready: it accepts a transfer in every cycle where `valid` is high, and it does
  not look at the burst FSM to decide that. The wrapper controls only what it must (enable, mode and window inputs).
- A single value sent to another module (the coarse word, a phase correction) is a pulse: `<name>_valid_o` and `<name>_o` on the sender,
  `<name>_valid_i` and `<name>_i` on the receiver. The receiver loads it in the cycle where `valid` is high.
- `valid` is high for exactly one cycle per transfer. Data is meaningful only while `valid` is high.
- Error estimators report their error with a valid (`err_valid_o`, `err_o`). The wrapper aligns it with the output symbol.
- Control, status and DFT signals are plain signals.
- Angles are in binary radians: an unsigned fraction of a turn that wraps by itself (`2^N` is one turn).

Do:

```systemverilog
module derotator (
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic               s_axis_valid_i,
  input  logic signed [15:0] s_axis_i_sym_i,
  input  logic signed [15:0] s_axis_q_sym_i,
  input  logic               coarse_valid_i,    // one pulse, loads the frequency word
  input  logic        [23:0] coarse_word_i,
  input  logic               freq_adj_valid_i,
  input  logic signed [15:0] freq_adj_i,
  input  logic               phase_adj_valid_i,
  input  logic        [31:0] phase_adj_i,       // binary radians
  output logic               m_axis_valid_o,
  output logic signed [15:0] m_axis_i_sym_o,
  output logic signed [15:0] m_axis_q_sym_o
);
```

Don't:

```systemverilog
module derotator (
  input  logic        clk_i,
  input  logic        sym_valid_i,           // unclear names
  output logic        sym_ready_o,           // no ready signals
  input  logic [31:0] s_axis_tdata,          // packed I and Q
  output logic [31:0] m_axis_tdata
);
```

## 4. Widths, literals and signed arithmetic

**Give every literal an explicit width. Make width changes explicit with casts or concatenation. Never
rely on implicit truncation or extension.** [lowRISC]

Do:

```systemverilog
logic [3:0] cnt_d, cnt_q;
assign cnt_d = cnt_q + 4'd1;
assign sum_wide = {{4{a_i[11]}}, a_i} + {{4{b_i[11]}}, b_i};   // explicit sign extension
```

Don't:

```systemverilog
assign cnt_d    = cnt_q + 1;      // unsized literal
assign narrow_o = wide_q;         // silent truncation
```

**Cast before mixing signed and unsigned operands. Do not ignore signed/unsigned warnings.** [lowRISC]

Do:

```systemverilog
assign diff = $signed({1'b0, unsigned_val}) - signed_val;
```

Don't:

```systemverilog
assign diff = unsigned_val - signed_val;   // whole expression silently becomes unsigned
```

## 5. Sequential logic and reset

**Registers use `always_ff` and non-blocking assignments only. Keep next-state logic in a separate
`always_comb` block or `assign`. Never assign the same register in two blocks.** [lowRISC]

Do:

```systemverilog
always_comb begin
  acc_d = acc_q;
  if (in_valid_i) begin
    acc_d = acc_q + in_i;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    acc_q <= '0;
  end else begin
    acc_q <= acc_d;
  end
end
```

Don't:

```systemverilog
always @(posedge clk_i) begin      // plain always, mixes logic and state
  if (in_valid_i) acc = acc + in_i;    // blocking assignment in a clocked block
end
```

**Reset style.** [lowRISC, with a project decision to confirm]
The lowRISC guide uses an active-low asynchronous reset (`rst_ni`). Use it for control and state
registers. Datapath registers that Vivado must pack into DSP48 or block RAM may need a synchronous
reset or no reset, as described in UG901. Check this in the day-one synthesis test, and record the
final choice here:

> Decision: _to be filled after the first Vivado synthesis test_.

## 6. Combinational logic and case statements

**Use `always_comb` (no sensitivity list) with blocking assignments. Give every output of the block a
default value before the logic, so no latch can be inferred.** [lowRISC]

Do:

```systemverilog
always_comb begin
  mu_d = mu_q;
  if (strobe_i) begin
    mu_d = mu_new_i;
  end
end
```

Don't:

```systemverilog
always_comb begin
  if (strobe_i) begin
    mu_d = mu_new_i;      // mu_d is not assigned otherwise: latch
  end
end
```

**Use `unique case` and always include a `default`. Never use `casex`, `full_case` or `parallel_case`.** [lowRISC]

Do:

```systemverilog
always_comb begin
  slice_o = 2'd0;
  unique case (level_i)
    2'b00:   slice_o = 2'd0;
    2'b01:   slice_o = 2'd1;
    default: slice_o = 2'd2;
  endcase
end
```

Don't:

```systemverilog
always_comb begin
  casex (level_i)            // casex matches X as a wildcard
    2'b0x: slice_o = 2'd0;   // no default
  endcase
end
```

## 7. Finite state machines

**Define states with an enum (`UpperCamelCase` names, type ending in `_e`). Use one `always_comb` block for
next state and outputs, and one `always_ff` block for the state register. Set a default state and handle
illegal encodings in `default`.** [lowRISC / UG901]

Do:

```systemverilog
typedef enum logic [2:0] {
  WaitBurst, Acquire, CoarseEst, Load, CostasAcq, QuadCheck, Track
} burst_state_e;

burst_state_e state_d, state_q;

always_comb begin
  state_d = state_q;
  unique case (state_q)
    WaitBurst: if (in_valid_i) state_d = Acquire;
    Acquire:   if (str_lock_i) state_d = CoarseEst;
    default:   state_d = WaitBurst;
  endcase
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    state_q <= WaitBurst;
  end else begin
    state_q <= state_d;
  end
end
```

Don't:

```systemverilog
reg [2:0] state;                    // raw numbers, no enum
always @(posedge clk_i) begin       // state, next state and outputs in one block
  case (state)
    0: if (in_valid_i) state <= 1;
    1: if (str_lock_i) state <= 2;
  endcase                           // no default, no reset
end
```

Every FSM is documented in its module document (state table, transition table, reset state).

## 8. Fixed-point arithmetic

All arithmetic is fixed-point. These rules are **[Project]**.

**Take widths and formats from the golden model, and keep them in `code/rtl/pkg/`. Never hard-code a
width in a module.**

**Grow the width before an add or multiply, then reduce it in one place with an explicit rounding and
saturation step.**

**Mark every state register `// SATURATING` or `// WRAPPING` at its declaration.**
Carrier phase accumulators and the modulo-1 counter wrap by design. The PI integrator and PI output
saturate.

Do:

```systemverilog
logic signed [AccW-1:0] acc_q;     // SATURATING
logic signed [AccW:0]   acc_full;  // one extra bit for the add

assign acc_full = {acc_q[AccW-1], acc_q} + {term_i[TermW-1], term_i};

always_comb begin
  acc_d = acc_q;
  if (in_valid_i) begin
    if (acc_full > AccMax)       acc_d = AccMax;
    else if (acc_full < AccMin)  acc_d = AccMin;
    else                         acc_d = acc_full[AccW-1:0];
  end
end
```

Don't:

```systemverilog
logic signed [AccW-1:0] acc_q;
assign acc_d = acc_q + term_i;     // overflow wraps silently, extra bit dropped
```

## 9. Valid / strobe convention

These rules are **[Project]**. Streams have `valid` and no `ready` (section 3).

**A register that advances once per sample or per symbol updates only when the `valid` of its input stream (or an internal strobe
derived from it) is high. Data on a stream is meaningful only while its `valid` is high.** The symbol-rate parts (the PI
filters, the NCO, the coarse delay chain) advance on the symbol strobe, not on every clock.

Do:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    freq_q <= '0;
  end else if (s_axis_valid_i) begin
    freq_q <= freq_d;
  end
end
```

Don't:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) freq_q <= '0;
  else         freq_q <= freq_d;     // advances every clock, not every symbol
end
```

**Prefer registered module outputs.** [lowRISC]

## 10. Vivado inference (UG901)

**Write memories so that Vivado infers block RAM or ROM: a synchronous (registered) read. An asynchronous
read becomes distributed LUT RAM.** [UG901]
ROM and RAM contents come from `data/mem/` with `$readmemh`. This is the only permitted `initial` block in
design files. Pass the file name as a parameter.

Do:

```systemverilog
logic [DataW-1:0] mem [2**AddrW];
logic [DataW-1:0] rd_data_q;

initial begin
  $readmemh(MemFile, mem);   // only permitted use of initial in design files
end

always_ff @(posedge clk_i) begin
  rd_data_q <= mem[rd_addr_i];
end
```

Don't:

```systemverilog
assign rd_data_o = mem[rd_addr_i];   // asynchronous read: LUT RAM, not block RAM
```

**Register the inputs and the output of every multiplier so Vivado maps it to a DSP48. Do not chain several
multiplies and adds in one cycle without registers.** [UG901]

Do:

```systemverilog
always_ff @(posedge clk_i) begin
  a_q    <= a_i;
  b_q    <= b_i;
  prod_q <= a_q * b_q;     // a_q, b_q, prod_q declared signed
end
```

Don't:

```systemverilog
assign y_o = (a_i * b_i) + (c_i * d_i) + e_i;   // long unregistered path, poor DSP mapping
```

## 11. Forbidden in design files

These constructs are not allowed in `code/rtl/`. [lowRISC / Project]

- Delays (`#`) and `initial` blocks, except the memory load in section 10.
- `casex`, `full_case`, `parallel_case`, `defparam`, `.*` port connections, tri-state logic.
- Tasks, classes, queues, dynamic arrays, `real`, `string`, `$random`, `$display` in logic.
- Hierarchical references.
- Latches (flag any `always_latch` for review).
- Floating `begin`/`end` blocks outside a `for`, `if` or `case`.

## 12. Verification

These rules are **[Project]**.

- Testbenches live in `code/tb/` and may use any SystemVerilog feature.
- **Random cases come from the SV generator** (`code/tb/gen`). Randomise integers and derive real values
  from them (for example `tau = int / 1024`), because `rand real` does not work in constraints.
- Testbenches read vectors and expected outputs from `data/vectors/`. They do not generate stimulus or
  expected values themselves.
- Every case list records the generator seed and the noise seed, so any failing burst can be rerun.
- Generated files (waveforms, logs, coverage, reports) go to `out/` and are never committed.

## 13. Lint, review and definition of done

- Questa Lint must be clean. Each waiver in `code/lint/waivers/` carries a one-line reason.
- Review the Vivado synthesis warnings for latches, width mismatches and unconnected ports before merging.
- A module is done when:
  1. lint is clean,
  2. synthesis is clean,
  3. its outputs match the golden model on the agreed vectors,
  4. its module document in `docs/modules/` is up to date.
