// Standalone Constrained-Random Scenario Generator for coarse_cfo_core
// Combines full-chain bursts (gen_mode=0) and standalone block corner cases (gen_mode=1, corner=1).
module gen_coarse_cases;

    class coarse_cfg;
        rand bit [31:0] seed;
        rand int        N_payload;
        rand int        snr_x100;
        rand int        cfo_q24;
        rand int        tau_q16;
        rand int        phase_q24;
        int             gen_mode;
        int             corner_tag;
        int             cfo_mode; // 0: zero, 1: sm_pos, 2: sm_neg, 3: lg_pos, 4: lg_neg, 5: q2_q3, 6: Q3, 7: Q2

        constraint c_seed { seed != 32'd0; }
        constraint c_len  { N_payload inside {[120 : 180]}; }
        constraint c_snr  { snr_x100 inside {[1200 : 2800]}; }
        constraint c_tau  { tau_q16 inside {[0 : 65535]}; }
        constraint c_ph   { phase_q24 inside {[-8388608 : 8388607]}; }
        constraint c_cfo {
            if (cfo_mode == 0)      cfo_q24 == 0;
            else if (cfo_mode == 1) cfo_q24 inside {[8388    : 67108]};     // +0.0005 .. +0.004 (small_pos)
            else if (cfo_mode == 2) cfo_q24 inside {[-67108  : -8388]};     // -0.004  .. -0.0005 (small_neg)
            else if (cfo_mode == 3) cfo_q24 inside {[503316  : 1509949]};   // +0.03   .. +0.09 (large_pos)
            else if (cfo_mode == 4) cfo_q24 inside {[-1509949 : -503316]};  // -0.09   .. -0.03 (large_neg)
            else if (cfo_mode == 6) cfo_q24 inside {[-1845493 : -1342177]}; // -0.11..-0.08 -> 4*cfo in (-0.44,-0.32) turns (CORDIC Q3)
            else if (cfo_mode == 7) cfo_q24 inside {[1342177  : 1845493]};  // +0.08..+0.11 -> 4*cfo in (+0.32,+0.44) turns (CORDIC Q2)
            else                    cfo_q24 dist {[-2013265:-1258291] := 50, [1258291:2013265] := 50};
        }
    endclass

    class coarse_cyc;
        rand bit          s_valid;
        rand bit          force_en;
        rand logic [23:0] force_cfo;
        constraint c_v { s_valid dist {1 := 80, 0 := 20}; }
        constraint c_f {
            force_en dist {0 := 85, 1 := 15};
            force_cfo dist {[-60000:-2000] := 35, [2000:60000] := 35, [-4000000:-500000] := 15, [500000:4000000] := 15};
        }
    endclass

    initial begin
        int        fd, num_cases;
        coarse_cfg cfg;
        coarse_cyc cyc;
        bit        rst_n, start_i, s_val, fc_en;
        int        total_cycles, valid_cnt;
        string     fname;

        num_cases = 10;
        void'($system("if not exist cases mkdir cases"));
        cfg = new();
        cyc = new();

        for (int c = 1; c <= num_cases; c++) begin
            cfg.gen_mode   = (c <= 2) ? 0 : 1;
            cfg.corner_tag = (c <= 2) ? 0 : 1;
            case (c)
                1: cfg.cfo_mode = 3; // full-chain large pos
                2: cfg.cfo_mode = 4; // full-chain large neg
                3: cfg.cfo_mode = 1; // unit small_pos
                4: cfg.cfo_mode = 2; // unit small_neg + >32 syms
                5: cfg.cfo_mode = 0; // unit zero + force_en pos/neg
                6: cfg.cfo_mode = 5; // unit high CFO corner
                7: cfg.cfo_mode = 3; // unit multi-window + force_cfo_en
                8: cfg.cfo_mode = 4; // unit mid-StIterate reset -> StIdle
                9: cfg.cfo_mode = 6; // unit guaranteed CORDIC Q3 (-pi + z)
                default: cfg.cfo_mode = 7; // unit guaranteed CORDIC Q2 (pi - z)
            endcase

            if (!cfg.randomize()) $fatal(1, "Randomization failed on coarse cfg");

            if (cfg.gen_mode == 0)
                total_cycles = (190 + cfg.N_payload) * 4 + 32;
            else
                total_cycles = 260;

            fname = $sformatf("cases/cfg_tc_%02d.txt", c);
            fd = $fopen(fname, "w");
            if (fd == 0) $fatal(1, "Could not open %s", fname);

            $fwrite(fd, "# MODULE coarse CASE %02d\n", c);
            $fwrite(fd, "CFG %0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
                    cfg.seed, cfg.gen_mode, cfg.corner_tag, cfg.N_payload,
                    cfg.snr_x100, cfg.cfo_q24, cfg.tau_q16, cfg.phase_q24, total_cycles);

            valid_cnt = 0;
            for (int t = 0; t < total_cycles; t++) begin
                if (!cyc.randomize()) $fatal(1, "Randomization failed on coarse mask");
                rst_n   = 1'b1;
                start_i = 1'b0;
                s_val   = 1'b1;
                fc_en   = 1'b0;

                if (cfg.gen_mode == 0) begin
                    // Full-chain sample mask (start_i driven from wrapper FSM in MATLAB)
                    s_val = (t < total_cycles - 32) ? (t < 8 ? 1'b1 : cyc.s_valid) : 1'b0;
                    fc_en = 1'b0;
                end else if (c == 4) begin
                    // >32 valid symbols while start_i remains 1 (hits count_q < 32 == 0)
                    start_i = (t >= 4 && t < 110);
                    s_val   = (t >= 4 && t < 110) ? (t < 50 ? 1'b1 : cyc.s_valid) : 1'b0;
                end else if (c == 5) begin
                    // Zero CFO window, then force_cfo_en window
                    start_i = (t >= 4 && t < 80);
                    s_val   = (t >= 4 && t < 80);
                    fc_en   = (t >= 140 && t < 165) ? cyc.force_en : 1'b0;
                end else if (c == 7) begin
                    // Back-to-back windows + force override
                    start_i = ((t >= 4 && t < 75) || (t >= 120 && t < 200));
                    s_val   = start_i ? cyc.s_valid : 1'b0;
                    fc_en   = (t >= 205 && t < 235) ? cyc.force_en : 1'b0;
                end else if (c == 8) begin
                    // Active mid-CORDIC StIterate reset -> hits CORDIC StIterate -> StIdle!
                    start_i = (t >= 4 && t < 80) || (t >= 120 && t < 210);
                    s_val   = ((t >= 4 && t < 44) || (t >= 120 && t < 190));
                    if (t >= 42 && t < 46) begin // ~6 clocks after 32nd symbol completes accumulation
                        rst_n = 1'b0;
                    end
                end else begin
                    // Two windows cleanly spaced in standalone symbol cycles
                    start_i = ((t >= 4 && t < 85) || (t >= 130 && t < 215));
                    s_val   = start_i ? (t < 15 ? 1'b1 : cyc.s_valid) : 1'b0;
                end

                $fwrite(fd, "%0d %0d %0d %0d %06x\n", rst_n, start_i, s_val, fc_en, cyc.force_cfo);
            end
            $fclose(fd);
            $display("[GEN_COARSE] Wrote %s (mode=%0d, seed=%0d, cfo_q24=%0d, cyc=%0d)",
                     fname, cfg.gen_mode, cfg.seed, cfg.cfo_q24, total_cycles);
        end
    end
endmodule
