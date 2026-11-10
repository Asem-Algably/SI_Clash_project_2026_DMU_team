# Coarse CFO Estimator

## 1. Overview
This repository contains the RTL design and verification of the **Coarse Carrier Frequency Offset (CFO) Estimator**. The module estimates the CFO from the preamble symbols to initialize the Costas loop, ensuring it starts close to the correct frequency.

The implementation is fully **bit-accurate** and adheres to the **lowRISC SystemVerilog Coding Style Guide**. It features a blind estimation algorithm (Conjugate Auto-Correlation) that operates on STR output symbols at the symbol rate.

**Spec Limits Achieved:**
*   **CFO Range:** -0.10 to +0.10 Rsym (R.113).
*   **Accuracy:** Within ±0.5% of Rsym over 0 to 20 dB SNR (CP3).
*   **Latency:** 64 symbols window (R.116).
*   **Algorithm:** Preamble-assisted, blind (R.115).

---

## 2. Architecture & Operation

The estimator uses a lag \(D = 4\) and a window of \(N = 64\) symbols. The datapath consists of the following stages:

1.  **Delay Line:** Four symbol-rate registers. The last stage stores the **conjugate** of the older sample (by negating the Q component).
2.  **Complex Multiplier:** Computes \(r[n] \cdot \text{conj}(r[n-4])\).
3.  **Accumulator:** Accumulates the complex products over the 64-symbol window.
4.  **CORDIC:** Computes the angle of the accumulated sum (fraction of a turn).
5.  **Frequency Calculation:** Right-shifts the angle by 2 (`>> 2`) to divide by the lag \(D=4\), resulting in turns per symbol.

---

## 3. Interface & Signals

### 3.1. Core Module (`coarse_cfo_core.sv`)
This module contains the pure algorithm and datapath.

| Signal Name | Dir | Width / Format | Description |
| :--- | :--- | :--- | :--- |
| `clk_i` | in | 1 | Clock |
| `rst_ni` | in | 1 | Active-low asynchronous reset |
| `start_i` | in | 1 | Start collecting a window |
| `s_axis_valid_i` | in | 1 | Symbol strobe from STR |
| `s_axis_i_sym_i` | in | 16-bit signed | STR output symbol, I (Q1.15) |
| `s_axis_q_sym_i` | in | 16-bit signed | STR output symbol, Q (Q1.15) |
| `m_axis_valid_o` | out | 1 | Estimate ready (one pulse) |
| `m_axis_cfo_o` | out | 24-bit signed | Estimate in turns per symbol (Q2.22) |
| `force_cfo_en_i` | in | 1 | Override enable (for DFT) |
| `force_cfo_i` | in | 24-bit | Override value |

### 3.2. AXI Wrapper (`coarse_cfo_axi_wrapper.sv`)
This module wraps the core with an AXI4-Lite interface for control/status and an AXI4-Stream interface for data.

| Signal Name | Dir | Width | Description |
| :--- | :--- | :--- | :--- |
| `s00_axi_aclk` | in | 1 | AXI Clock |
| `s00_axi_aresetn` | in | 1 | AXI Active-low reset |
| `s_axis_tdata_re` | in | 16-bit | AXI-Stream I symbol in |
| `s_axis_tdata_im` | in | 16-bit | AXI-Stream Q symbol in |
| `s_axis_tvalid` | in | 1 | AXI-Stream Valid |
| `s_axis_tready` | out | 1 | AXI-Stream Ready |
| `start_of_burst` | in | 1 | Burst start trigger |
| `m_axis_cfo_est` | out | 24-bit | Estimate output to Costas Loop |
| `m_axis_tvalid` | out | 1 | Estimate valid pulse |
| `dft_sel` | in | 4-bit | DFT MUX select |
| `dft_obs_data` | out | 32-bit | DFT observation data |

---

## 4. Configuration Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `DataWidth` | 16 | Input symbol width |
| `Lag` | 4 | Delay in symbols (must be even) |
| `WinLen` | 64 | Number of symbols accumulated |
| `AccWidth` | 40 | Accumulator bit-width |

---

## 5. Verification & Results

The design was verified using QuestaSim. The testbenches output data files (`cfo_output_tb3.txt` and `cfo_output_tb5.txt`) to serve as inputs for the subsequent Costas Loop module.

### 5.1. Checkpoint 3 (Core Accuracy)
A pure tone sweep was injected into the core to verify bit-accuracy.

| CFO_in (Rsym) | Raw Output (24-bit) | est_as_Rsym |
| :--- | :--- | :--- |
| -0.1000 | -1677751 | -0.100002 |
| -0.0500 | -838890 | -0.050002 |
| 0.0000 | -77 | -0.000005 |
| +0.0500 | 838889 | +0.050002 |
| +0.1000 | 1677751 | +0.100002 |

*Result: The error is well within the ±0.5% spec limit (maximum observed error is ~0.000005).*

### 5.2. Checkpoint 5 (DFT MUX & AXI)
The DFT MUX correctly displays internal signals, and the AXI interface successfully writes and reads back the correct values.

*   **AXI Write/Read:** `[PASS] SLV_REG0: 0xdeadbeef`
*   **DFT MUX (CFO = 0.05 Rsym):** `dft_sel=0 -> 0x000ccce9` (which equals 838889 decimal).
*   **AXI Read (Addr 0x04):** `0x000ccce9`

### 5.3. Generated Output Files
The testbenches generate the following output files, which can be read by the next stage (Costas Loop Testbench) using `$fscanf`:

*   `cfo_output_tb3.txt`:
    ```text
    -0.100000 e66649  -1677751
    -0.075000 eccce9  -1258263
    0.050000 0ccce9    838889
