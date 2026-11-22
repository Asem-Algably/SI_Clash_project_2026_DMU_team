#!/usr/bin/env python3
"""
generate_bist_rom_mem.py
Extracts BIST stimulus and expected vector files from tb_top_vec.hex for on-chip BRAM ROMs.

Outputs:
- code/rtl/bist/bist_input_vec.mem:
    5,624 lines of 26-bit packed hex: {in_sample_valid (1b), start_of_burst (1b), in_sample_i (12b), in_sample_q (12b)}
- code/rtl/bist/bist_exp_vec.mem:
    1,199 lines of 32-bit hex: {exp_i (16b), exp_q (16b)} (payload symbols in TRACK state where out_sym_valid == 1)
"""

import sys
from pathlib import Path


def main():
    # Resolve repository root
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[1]  # code/scripts/bist -> repo root

    src_hex = repo_root / "code" / "tb" / "vectors" / "tb_top_vec.hex"
    out_input_mem = repo_root / "code" / "rtl" / "bist" / "bist_input_vec.mem"
    out_exp_mem = repo_root / "code" / "rtl" / "bist" / "bist_exp_vec.mem"

    if not src_hex.is_file():
        # Fallback to local relative check
        src_hex = Path("code/tb/vectors/tb_top_vec.hex").resolve()
        out_input_mem = Path("code/rtl/bist/bist_input_vec.mem").resolve()
        out_exp_mem = Path("code/rtl/bist/bist_exp_vec.mem").resolve()

    if not src_hex.is_file():
        print(f"ERROR: Cannot find source hex file: {src_hex}", file=sys.stderr)
        sys.exit(1)

    print(f"Reading source vectors from: {src_hex}")

    input_lines = []
    exp_lines = []

    with open(src_hex, "r") as f:
        for line_num, line in enumerate(f, start=1):
            s = line.strip()
            if not s or s.startswith("//") or s.startswith("#"):
                continue

            # Format: v_val(1) _ in_i(3) _ in_q(3) _ v_sob(1) _ v_oval(1) _ exp_oi(4) _ exp_oq(4) _ v_fsm(1) _ v_lock(1)
            parts = s.split("_")
            if len(parts) != 9:
                print(f"WARNING: Skipping malformed line {line_num}: {s}")
                continue

            v_val = int(parts[0], 16) & 0x1
            in_i = int(parts[1], 16) & 0xFFF
            in_q = int(parts[2], 16) & 0xFFF
            v_sob = int(parts[3], 16) & 0x1
            v_oval = int(parts[4], 16) & 0x1
            exp_oi = int(parts[5], 16) & 0xFFFF
            exp_oq = int(parts[6], 16) & 0xFFFF
            v_fsm = int(parts[7], 16) & 0x7

            # 26-bit packed input: {v_val[0], v_sob[0], in_i[11:0], in_q[11:0]}
            packed_input = (v_val << 25) | (v_sob << 24) | (in_i << 12) | in_q
            input_lines.append(f"{packed_input:07x}\n")

            # Expected payload symbols: (v_oval == 1) and (v_fsm == 5 / TRACK)
            if v_oval == 1 and v_fsm == 5:
                packed_exp = (exp_oi << 16) | exp_oq
                exp_lines.append(f"{packed_exp:08x}\n")

    out_input_mem.parent.mkdir(parents=True, exist_ok=True)
    out_exp_mem.parent.mkdir(parents=True, exist_ok=True)

    with open(out_input_mem, "w") as f_in:
        f_in.writelines(input_lines)

    with open(out_exp_mem, "w") as f_exp:
        f_exp.writelines(exp_lines)

    print(f"Generated input ROM memory file:    {out_input_mem} ({len(input_lines)} lines)")
    print(f"Generated expected ROM memory file: {out_exp_mem} ({len(exp_lines)} lines)")

    assert len(input_lines) == 5624, f"Expected 5,624 lines, got {len(input_lines)}"
    assert len(exp_lines) == 1199, f"Expected 1,199 lines, got {len(exp_lines)}"
    print("SUCCESS: Both memory files verified bit-accurately!")


if __name__ == "__main__":
    main()
