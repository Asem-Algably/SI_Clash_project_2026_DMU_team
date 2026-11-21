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

![Layout view from the IC Compiler GUI](images/layout.png)

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

The post-roting column is from the *QoR Report for physical synthesis
(after routing)*. Area grew about 3% from synthesis to placement.

![QoR report, after routing](images/after routing.png)

*QoR report for physical synthesis (after routing): timing, cell count and area.*

![Area and design rules](images/area_design_rules.png)

*Area, net length and design rule summary (0 nets with violations, 0 max transition, 0 max capacitance).*

![Cell count and area summary](images/cell_count_area.png)

*Cell and area summary from `icc_shell`: 5,141 cells, 856 sequential and 4,276 combinational in the top-level design, 50,401 µm² total cell area.*

> The 5,141-cell / 856-flop figures here cover only the top level of the
> hierarchy; the full design is the 28,617 leaf cells and 2,011 flops shown in
> the QoR report above.

### 6.2 Placement legality

Cells not on row, cell overlaps, overlaps with blockages, orientation
violations, site violations and power-strap violations are all **0**, for both
fixed and non-fixed cells. The tool warns that the die area is not an integer
multiple of the minimum site height, which does not affect legality.

![Placement legality check](images/placement_legality.png)

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

## 7. Notes on file size

The ~52 MB GDS is consistent with this design. The floorplan runs at 25%
core utilization, so most of the core is filler cells, and the design has
~28.6k cells, 32.7k routed nets, redundant vias and a full power mesh.
The size alone is not an indicator of a problem.

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
