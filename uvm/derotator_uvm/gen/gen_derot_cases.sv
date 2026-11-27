// Standalone Constrained-Random Scenario Generator for derotator
// Combines full-chain bursts (gen_mode=0) and standalone block NCO sweeps (gen_mode=1, corner=2).
module gen_derot_cases;

    class derot_cfg;
        rand bit [31:0] seed;
        rand int        N_payload;
        rand int        snr_x100;
        rand int        cfo_q24;
        rand int        tau_q16;
        rand int        phase_q24;
        int             gen_mode;
        int             corner_tag;
        int             sign_dir;

        constraint c_seed { seed != 32'd0; }
        constraint c_len  { N_payload inside {[140 : 200]}; }
        constraint c_snr  { snr_x100 inside {[1200 : 2600]}; }
        constraint c_tau  { tau_q16 inside {[0 : 65535]}; }
        constraint c_ph   { phase_q24 inside {[-8388608 : 8388607]}; }
        constraint c_cfo  {
            if (sign_dir > 0) cfo_q24 inside {[503316 : 2013265]};    // +0.03 .. +0.12
            else              cfo_q24 inside {[-2013265 : -503316]};  // -0.12 .. -0.03
        }
    endclass

    class derot_cyc;
        rand bit          s_valid;
        rand bit          f_valid;
        rand bit          force_en;
        rand logic [31:0] force_freq;
        constraint c_v { s_valid dist {1 := 75, 0 := 25}; }
        constraint c_f {
            f_valid  dist {0 := 70, 1 := 30};
            force_en dist {0 := 80, 1 := 20};
            force_freq inside {[32'h0500_0000 : 32'h3FFF_FFFF]};
        }
    endclass

    initial begin
        int       fd, num_cases;
        derot_cfg cfg;
        derot_cyc cyc;
        bit       rst_n, s_val, c_val, f_val, p_val, ff_en;
        int       total_cycles, reset_clk;
        string    fname;

        num_cases = 8;
        void'($system("if not exist cases mkdir cases"));
        cfg = new();
        cyc = new();

        for (int c = 1; c <= num_cases; c++) begin
            cfg.gen_mode   = (c <= 2) ? 0 : 1;
            cfg.corner_tag = (c <= 2) ? 0 : 2;
            cfg.sign_dir   = (c % 2 == 1) ? 1 : -1;
            if (!cfg.randomize()) $fatal(1, "Randomization failed on derot cfg");

            total_cycles = (cfg.gen_mode == 0) ? ((190 + cfg.N_payload) * 4 + 32) : 280;
            reset_clk    = 140;

            fname = $sformatf("cases/cfg_tc_%02d.txt", c);
            fd = $fopen(fname, "w");
            if (fd == 0) $fatal(1, "Could not open %s", fname);

            $fwrite(fd, "# MODULE derot CASE %02d\n", c);
            $fwrite(fd, "CFG %0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
                    cfg.seed, cfg.gen_mode, cfg.corner_tag, cfg.N_payload,
                    cfg.snr_x100, cfg.cfo_q24, cfg.tau_q16, cfg.phase_q24, total_cycles);

            for (int t = 0; t < total_cycles; t++) begin
                if (!cyc.randomize()) $fatal(1, "Randomization failed on derot mask");
                rst_n = 1'b1;
                c_val = 1'b0;
                p_val = 1'b0;
                ff_en = 1'b0;

                if (cfg.gen_mode == 0) begin
                    s_val = (t < total_cycles - 32) ? (t < 8 ? 1'b1 : cyc.s_valid) : 1'b0;
                    f_val = 1'b0;
                end else begin
                    s_val = (t >= 4 && t < total_cycles - 12) ? ((t < 10) ? 1'b1 : cyc.s_valid) : 1'b0;
                    c_val = (t == 4) || (t == 160);
                    f_val = (t > 20 && t < total_cycles - 12) && cyc.f_valid;
                    // Pulse phase_adj_valid (with 0->1 rising edges) across runs
                    p_val = (t == 40) || (t == 100) || (t == 210);
                    ff_en = (c == 7) && (t >= 170 && t < 230) && cyc.force_en;
                    if (c == 8 && (t >= reset_clk && t < reset_clk + 3)) begin
                        rst_n = 1'b0;
                        s_val = 1'b0;
                    end
                end

                $fwrite(fd, "%0d %0d %0d %0d %0d %0d %08x\n",
                        rst_n, s_val, c_val, f_val, p_val, ff_en, cyc.force_freq);
            end
            $fclose(fd);
            $display("[GEN_DEROT] Wrote %s (mode=%0d, seed=%0d, cfo=%0d, cyc=%0d)",
                     fname, cfg.gen_mode, cfg.seed, cfg.cfo_q24, total_cycles);
        end
    end
endmodule
