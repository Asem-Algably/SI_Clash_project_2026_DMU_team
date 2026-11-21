# sync_system_top — ASIC Implementation (Nangate 45 nm)

Burst-mode receive synchronizer (symbol timing recovery, coarse CFO, derotator,
Costas loop, burst controller) taken through synthesis and place-and-route
with Synopsys Design Compiler and IC Compiler.

> **Status:** synthesis and placement are completed, meet Post-route timing, DRC and LVS results 
---

## 1. Summary

| Item | Value |
|---|---|
| Technology | NangateOpenCellLibrary PDK v1.3 (FreePDK45, 10 metal layers) |
| Corner | `ss0p95vn40c` (slow, 0.95 V, −40 °C), single corner |
| Clock | 5 ns (200 MHz) target; functional spec clock is 125 MHz (8 ns) |
| Leaf cells | 28,617 (26,606 combinational, 2,011 sequential) |
| Macros | 0 |
| Total cell area | 50,401 µm² (≈ 0.05 mm²) |
| Die size | ≈ 0.41 × 0.41 mm, inferred from the power pad coordinates (≈ 0.17 mm²) |
| Nets / net length | 32,670 nets, 778,323 µm |
| Output | GDS (~52 MB), Verilog netlists, SPEF |

---

## 1a. Layout

![Layout view from the IC Compiler GUI](<img width="848" height="320" alt="Screenshot 2026-11-21 185336" src="https://github.com/user-attachments/assets/6cf24ffc-770c-428b-befa-32601a5c3743" />
)

*Layout view from the IC Compiler GUI.*

---

## 2. Tools

| Stage | Tool | Version |
|---|---|---|
| Synthesis | Synopsys Design Compiler | G-2012.06-SP2 |
| Place & route | Synopsys IC Compiler | G-2012.06-ICC-SP2 |

---

## 3. Files

| File | Purpose |
|---|---|
| `syn.tcl` | Design Compiler script (`compile_ultra`, reports, netlist and SDC write) |
| `cons.tcl` | Timing constraints, shared by synthesis and P&R |
| `pnr.tcl` | Full ICC flow: floorplan → power → place → CTS → route → filler → GDS |
| `open_stage.tcl` | Re-open a saved Milkyway cell for inspection |
| `eco.tcl` | Apply an ECO, re-route, re-insert filler, verify, write GDS and netlists |
| `sync_system_top.v` | Synthesized netlist (pre-layout) |
| `sync_system_top.sdc` | SDC written by synthesis |
| `sync_system_top_icc.v` | Post-layout netlist with power/ground pins (`-pg`) |
| `sync_system_top_icc_nopg.v` | Post-layout netlist without power/ground pins |
| `synth_area.rpt`, `synth_cells.rpt`, `synth_qor.rpt`, `synth_resources.rpt`, `synth_timing.rpt` | Synthesis reports |

---

## 4. Constraints (`cons.tcl`)

```tcl
create_clock -name clk -period 5 -waveform {0 2.5} [get_ports clk]
set_input_delay  -max 1 -clock clk  [all_inputs except clk]
set_output_delay -max 1 -clock clk  [all_outputs]
set_clock_uncertainty 0.35 [get_clocks]
set_false_path -hold -from [all_inputs except clk]
set_false_path -hold -to   [all_outputs]
```

What this means for timing budgets:
 
- **Register-to-register paths** have the 5 ns period minus 0.35 ns of clock
  uncertainty.
- **Input-to-register and register-to-output paths** additionally lose the
  1 ns external delay, leaving roughly 3.65 ns.
- **Hold checks on inputs and outputs are not performed** (the false paths
  above); hold is checked on internal register-to-register paths.
- The 5 ns target is deliberately tighter than the 8 ns functional clock, so the
  implementation has margin at the spec frequency.

---

## 5. Flow

### Synthesis (`syn.tcl`)
`analyze` / `elaborate` → apply constraints → `compile_ultra` → write reports,
SDC, Verilog (`-hierarchy`) and DDC. The design keeps 9 hierarchical cells.

### Place and route (`pnr.tcl`)

1. Create the Milkyway library and import the synthesized netlist.
2. Floorplan: `-core_utilization 0.25`, 12.4 µm I/O-to-core spacing,
   routing limited to metal6 (metal7–10 reserved for the power mesh).
3. Power: rings on metal7–10, straps on metal6–10 (`synthesize_fp_rail`,
   `commit_fp_rail`), tap cells every 30 µm.
4. Placement: `place_opt`, `psynopt`, `check_legality`, tie-cell connection.
5. Clock tree: `clock_opt -only_cts`, `CLKBUF*` references,
   target skew 0.5 ns, max fanout 10, max transition 0.3 ns,
   non-default routing rule on metal3–5.
6. Spare cells: 20 × `NOR2_X4` / `NAND2_X4`, set `dont_touch`.
7. Routing: `route_opt` with hold fixing (preferred buffers `BUF_X1`/`BUF_X2`),
   SI options (delta delay, static noise, timing window), redundant via
   insertion, detail-route cleanup.
8. Filler insertion, `verify_zrt_route`, `verify_lvs`.
9. Output: GDS, `-pg` and no-pg netlists, SPEF.

---
### 6 Why each step matters
 
| Step | Purpose |
|---|---|
| Floorplan and power mesh | Define the die and deliver VDD/VSS to every cell through rings, straps and tap cells |
| `place_opt` | Places cells and optimizes timing and area together before the clock tree exists |
| Clock tree synthesis | Builds a buffered tree so every flop sees the clock at a similar time (skew) |
| Hold fixing | After CTS, short paths can violate hold; buffers are inserted to fix them (this is why buf/inv cells increase) |
| Spare cells | Unused gates left in the layout so a late fix (ECO) can be made without redoing the whole design |
| Redundant vias | Meant to improve yield by doubling vias where space allows; in this run 0 of 309,907 vias were converted (see 7.4) |
| Filler cells | Fill empty row space so the power rails and wells are continuous |
| `verify_zrt_route` / `verify_lvs` | Design-rule check and layout-versus-schematic check |
 
---

## 6. Results

### 6.1 Synthesis → sign-off

| Metric | Synthesis | sign-off |
|---|---|---|
| Leaf cells | 28,177 | 28,617 |
| Combinational cells | 26,166 | 26,606 |
| Sequential cells | 2,011 | 2,011 |
| Buf/Inv cells | 3,286 | 3,686 |
| Clock-tree buf/inv cells | 0 | 322 |
| Cell area | 48,960 µm² | 50,401 µm² |
| Critical path length | 3.61 ns | 2.84 ns |
| Levels of logic | 70 | 63 |
| Critical path slack (5 ns clock) | +0.01 ns | +1.00 ns |
| Total negative slack | 0.00 | 0.00 |
| Violating setup paths | 0 | 0 |
| Hold violations | 1,895 (worst −0.29 ns, ideal clock) | 0 |
| Max transition violations | 0 | 0 |
| Max capacitance violations | 0 | 0 |


(after routing)*. Area grew about 3% from synthesis to placement.

![Area and design rules](<img width="212" height="329" alt="Screenshot 2026-11-21 144433" src="https://github.com/user-attachments/assets/ed04de1c-6169-469e-b1fb-7914d5833a75" />
)

*QoR report for physical synthesis (after routing): timing, cell count and area.*
The post-roting column is from the *QoR Report for physical synthesis

![QoR report, after routing](<img width="170" height="201" alt="Screenshot 2026-11-21 144210" src="https://github.com/user-attachments/assets/ccf9ae12-bd49-403c-a8d2-fc9e7a187ce4" /> )

*Area, net length and design rule summary (0 nets with violations, 0 max transition, 0 max capacitance).*

![Cell count and area summary](<img width="311" height="182" alt="Screenshot 2026-11-21 101503" src="https://github.com/user-attachments/assets/bd6fce6a-9371-4d83-8c18-73676988e0f7" />
)

*Cell and area summary from `icc_shell`: 5,141 cells, 856 sequential and 4,276 combinational in the top-level design, 50,401 µm² total cell area.*

> The 5,141-cell / 856-flop figures here cover only the top level of the
> hierarchy; the full design is the 28,617 leaf cells and 2,011 flops shown in
> the QoR report above.

### 6.2 Placement legality

Cells not on row, cell overlaps, overlaps with blockages, orientation
violations, site violations and power-strap violations are all **0**, for both
fixed and non-fixed cells. The tool warns that the die area is not an integer
multiple of the minimum site height, which does not affect legality.

![Placement legality check](<img width="229" height="279" alt="Screenshot 2026-11-21 144449" src="https://github.com/user-attachments/assets/9d3d0640-9bc1-4bbf-a6fd-a7a17071639f" />
)

*`check_legality` report after placement.*

### 6.3 Area breakdown

| Block | Area (µm²) | Share | Cells | Flops |
|---|---|---|---|---|
| `lut_rom` (derotator sine table) | 11,407 | 22.6% | 10,173 | 30 |
| Derotator complex multiplier | 5,085 | 10.1% | 2,758 | 162 |
| Costas `pi_filter` | 4,249 | 8.4% | 1,772 | 202 |
| Coarse-CFO complex multiplier | 3,939 | 7.8% | 1,953 | 0 |
| STR interpolator (Q) | 3,560 | 7.1% | 1,473 | 252 |
| STR interpolator (I) | 3,536 | 7.0% | 1,451 | 252 |
| Costas `phase_error` | 2,781 | 5.5% | 1,347 | 102 |
| Coarse-CFO CORDIC | 2,610 | 5.2% | 1,339 | 135 |
| STR Gardner TED | 2,435 | 4.8% | 1,219 | 20 |
| Top-level logic (burst controller, modulo-1 NCO, STR PI, lock detectors, DFT mux, …) | 10,800 | 21.4% | ~5,130 | ~840 |

Cell and flop counts per block come from the post-layout netlist. The
sine look-up table is the largest single block because there is no ROM macro:
it is synthesized as random logic.

---

### 7 Routing and DRC results
 
Final detail route and via report, from the routed design:
 
| Item | Value |
|---|---|
| Open nets | 0 (0 frozen) |
| Detail-route violations | 0 |
| ORC summary, total violations | 0 |
| Total number of DRCs (after via step) | 0 |
| Routed nets | 32,646 |
| Total wire length | 1,060,765 µm |
| Total contacts (vias) | 309,907 |
| Total wires (segments) | 452,931 |
| Detail-route run time | 21 min 29 s real, 21 min 28 s CPU |
 
Wire length per layer:
 
| Layer | Length (µm) | Share |
|---|---|---|
| metal1 | 115,900 | 10.9% |
| metal2 | 329,885 | 31.1% |
| metal3 | 257,086 | 24.2% |
| metal4 | 178,983 | 16.9% |
| metal5 | 105,367 | 9.9% |
| metal6 | 73,543 | 6.9% |
| metal7–metal10 | 0 | 0% |
 
Signal routing stops at metal6 as intended; metal7–metal10 are used only for the
power rings and straps.
 
Vias per layer:
 
| Layer | Vias |
|---|---|
| via1 | 138,484 |
| via2 | 102,250 |
| via3 | 41,685 |
| via4 | 19,447 |
| via5 | 8,041 |
| **Total** | **309,907** |
 
![Detail route: 0 open nets, 0 violations, wire length per layer](<img width="1024" height="1024" alt="1 (2)" src="https://github.com/user-attachments/assets/ee75af04-4c1e-4de1-bcc3-c7b730085fd4" />

)
 
*Detail route summary: 0 open nets, 0 violations, wire length and contacts per layer.*
 
![Redundant via conversion report](<img width="1097" height="976" alt="2" src="https://github.com/user-attachments/assets/61d9d587-f30a-4ea0-a956-5cde810ba17c" />
)
 
*Redundant via report: 0.00% conversion (0 of 309,907 vias), 0 DRCs, antenna checking not active.*
 
Notes:
 
- The router reports that it merged away 355,780 aligned or redundant DRC
  markers during detail routing (message ZRT-305). That is the tool's internal
  bookkeeping while it iterates; the final count is 0.
- Redundant-via insertion ran but converted none of the vias (0.00%), so no
  double vias are present. Wire length is about 36% higher than the
  pre-route estimate of 778,323 µm, which is typical once real detour routing is
  done.
- Antenna checking was **not active** in this run, so antenna rule compliance
  has not been verified.
---
---

## 8. Known limitations

- **Low utilization.** 25% core utilization is far below a typical 60–70%.
  Raise `-core_utilization` if die area matters.
- **I/O constraints.** No `set_load` or `set_driving_cell`; I/O hold is
  false-pathed.
- **Supply voltage in power analysis.** `synthesize_fp_rail` and `analyze_fp_rail`
  use 1.1 V, while the timing corner is 0.95 V. Use 0.95 V for IR-drop numbers.
- **Clock skew target.** The CTS target skew of 0.5 ns is loose for a 5 ns
  period; check the achieved skew.
---

## 9. Reproducing

```sh
# Synthesis (Design Compiler)
dc_shell -f syn.tcl

# Place and route (IC Compiler)
icc_shell -f pnr.tcl

# Re-open the routed cell for inspection
icc_shell -f open_stage.tcl

# Apply an ECO and regenerate GDS / netlists
icc_shell -f eco.tcl
```

Paths in the scripts (`search_path`, PDK location, `../rtl`, `../syn/cons`)
are specific to the original machine and need adjusting.
