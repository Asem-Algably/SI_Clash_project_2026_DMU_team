// Standalone Constrained-Random Scenario Generator for sync_system_top
// Generates ONLY scenario configs, reproducible PRNG seeds for MATLAB,
// and cycle-by-cycle pin-level valid/control/force masks.
// Never generates sample data, internal states, or expected outputs.
module gen_top_cases;

    class top_burst_cfg;
        rand bit [31:0] seed;
        rand int        N_payload;
        rand int        snr_x100;
        rand int        cfo_q24;       // signed, 2^24 = 1.0 turn/sym
        rand int        tau_q16;       // unsigned, 2^16 = 1.0 sym (fixed once per burst!)
        rand int        phase_q24;     // signed, [-2^23, 2^23-1] = [-pi, +pi)
        rand bit [1:0]  init_mod;      // 0: QPSK, 1: QAM16
        rand bit        do_mod_switch; // runtime mid-burst mod_type switch
        rand bit        early_watchdog;
        rand bit        do_force;
        rand bit        do_mid_reset;
        int             case_id;
        int             forced_mod_dir = -1; // -1 = unconstrained
        int             forced_cfo_sign = 0; // -1 neg, +1 pos, 0 any

        constraint c_seed { seed != 32'd0; }
        constraint c_len  { N_payload inside {[160 : 260]}; }
        constraint c_snr  { snr_x100 dist {[900:1350] := 20, [1351:2200] := 60, [2201:3000] := 20}; }
        constraint c_tau  { tau_q16 inside {[0 : 65535]}; }
        constraint c_ph   { phase_q24 inside {[-8388608 : 8388607]}; }
        constraint c_mod  { init_mod inside {2'b00, 2'b01}; }
        constraint c_cfo {
            if (forced_cfo_sign > 0) {
                cfo_q24 inside {[335544 : 1677721]};   // +0.02 .. +0.10
            } else if (forced_cfo_sign < 0) {
                cfo_q24 inside {[-1677721 : -335544]}; // -0.10 .. -0.02
            } else {
                cfo_q24 dist {
                    [-1677721 : -335544] := 42,
                    [-335543  :  335543] := 16,
                    [ 335544  : 1677721] := 42
                };
            }
        }
        constraint c_flags {
            early_watchdog dist {0 := 85, 1 := 15};
            do_mod_switch  dist {0 := 60, 1 := 40};
            do_force       dist {0 := 70, 1 := 30};
            do_mid_reset   dist {0 := 92, 1 := 8};
        }
    endclass

    class cycle_mask_item;
        rand bit         in_val;
        rand bit         force_w_en;
        rand logic [15:0] force_w;
        rand bit         force_cfo_en;
        rand logic [23:0] force_cfo;
        rand bit         force_freq_en;
        rand logic [31:0] force_freq;

        constraint c_in_val { in_val dist {1 := 95, 0 := 5}; }
        constraint c_forces {
            force_w_en    dist {0 := 97, 1 := 3};
            force_cfo_en  dist {0 := 97, 1 := 3};
            force_freq_en dist {0 := 97, 1 := 3};
            force_w inside {[16'h3800 : 16'h4800]};
        }
    endclass

    initial begin
        int           fd, num_cases;
        top_burst_cfg cfg;
        cycle_mask_item cyc;
        bit           rst_n, in_val, sob, fw_en, fc_en, ff_en;
        bit [1:0]     cur_mod;
        bit [3:0]     dft_sel;
        int           rx_len, tail_len, total_cycles;
        int           wd_trigger_clk, reset_clk, stall_load_clk;
        int           switch_clk1, switch_clk2;
        string        fname;

        num_cases = 28;
        void'($system("if not exist cases mkdir cases"));

        cfg = new();
        cyc = new();

        for (int c = 1; c <= num_cases; c++) begin
            cfg.case_id = c;
            // Ensure balanced representation across CFO sign & initial modulation while keeping params random
            cfg.forced_cfo_sign = (c <= 14) ? 1 : -1;
            cfg.forced_mod_dir  = (c % 2);
            if (!cfg.randomize()) $fatal(1, "Randomization failed on burst cfg");
            // Enforce alternating start modulation cleanly alongside random switch flags
            cfg.init_mod = (c % 2 == 1) ? 2'b00 : 2'b01;
            // Guarantee at least 3 early-watchdog cases (in Acquire, CoarseEst, CostasAcq),
            // 6 runtime mod_switch cases, and 2 active mid-burst reset cases (per user request >1)
            cfg.early_watchdog = (c == 5 || c == 12 || c == 20);
            cfg.do_mod_switch  = ((c % 3) == 0 && c != 5 && c != 12 && c != 20);
            cfg.do_force       = (c == 4 || c == 7 || c == 11 || c == 16 || c == 22 || c == 25);
            cfg.do_mid_reset   = (c == 27 || c == 28);
            if (cfg.do_mid_reset) begin
                cfg.early_watchdog = 1'b0;
                cfg.do_force       = 1'b0;
            end

            rx_len   = (190 + cfg.N_payload) * 4;
            tail_len = 48; // >= 14 watchdog + 16 flush + margin
            if (cfg.early_watchdog) begin
                if (c == 5)       wd_trigger_clk = 120; // StAcquire -> Flush
                else if (c == 12) wd_trigger_clk = 340; // StCoarseEst -> Flush
                else              wd_trigger_clk = 620; // StCostasAcq -> Flush
                total_cycles = wd_trigger_clk + tail_len;
            end else if (cfg.do_mid_reset) begin
                wd_trigger_clk = -1;
                reset_clk      = (c == 27) ? 220 : 950; // StAcquire/CoarseEst vs StTrack
                total_cycles   = reset_clk + 120;
            end else begin
                wd_trigger_clk = -1;
                reset_clk      = -1;
                total_cycles   = rx_len + tail_len;
            end

            switch_clk1    = (190 * 4) + ($urandom_range(80, cfg.N_payload * 2));
            switch_clk2    = switch_clk1 + $urandom_range(80, 140);
            // Safe (<14) pause window targeting coarse_valid -> StLoad across bursts
            stall_load_clk = 380 + ((c * 19) % 140);
            dft_sel        = c[3:0];

            fname = $sformatf("cases/cfg_tc_%02d.txt", c);
            fd = $fopen(fname, "w");
            if (fd == 0) $fatal(1, "Could not open %s", fname);

            $fwrite(fd, "# MODULE top CASE %02d\n", c);
            $fwrite(fd, "CFG %0d 0 0 %0d %0d %0d %0d %0d %0d\n",
                    cfg.seed, cfg.N_payload, cfg.snr_x100, cfg.cfo_q24,
                    cfg.tau_q16, cfg.phase_q24, total_cycles);

            cur_mod = cfg.init_mod;
            for (int t = 0; t < total_cycles; t++) begin
                if (!cyc.randomize()) $fatal(1, "Randomization failed on cycle mask");

                rst_n  = 1'b1;
                sob    = (t == 0);
                dft_sel = dft_sel + 4'd1;

                // Determine valid mask
                if (cfg.early_watchdog && (t >= wd_trigger_clk)) begin
                    in_val = 1'b0;
                end else if (!cfg.early_watchdog && !cfg.do_mid_reset && (t >= rx_len)) begin
                    in_val = 1'b0;
                end else if (cfg.do_mid_reset && (t >= reset_clk)) begin
                    rst_n  = (t >= reset_clk + 3); // 3-clock active reset pulse
                    in_val = 1'b0;
                end else if (t < 8) begin
                    in_val = 1'b1; // clean burst entry
                end else if ((c <= 20) && (t >= stall_load_clk) && (t < stall_load_clk + 10)) begin
                    // 10-clock stall (< 14 watchdog) to stretch StLoad while rotating dft_sel
                    in_val = 1'b0;
                end else begin
                    in_val = cyc.in_val;
                end

                // Runtime mod_type switching mid-payload (0=>1 and 1=>0)
                if (cfg.do_mod_switch) begin
                    if (t == switch_clk1) cur_mod = (cfg.init_mod == 2'b00) ? 2'b01 : 2'b00;
                    if (t == switch_clk2) cur_mod = cfg.init_mod;
                end

                // Force overrides gated safely after lock/payload or mid-burst in force cases
                fw_en = cfg.do_force && (t > 200 && t < total_cycles - tail_len) && cyc.force_w_en;
                fc_en = cfg.do_force && (t > 900 && t < total_cycles - tail_len) && cyc.force_cfo_en;
                ff_en = cfg.do_force && (t > 900 && t < total_cycles - tail_len) && cyc.force_freq_en;

                $fwrite(fd, "%0d %0d %0d %1x %1x %0d %04x %0d %06x %0d %08x\n",
                        rst_n, in_val, sob, cur_mod, dft_sel,
                        fw_en, cyc.force_w, fc_en, cyc.force_cfo, ff_en, cyc.force_freq);
            end

            $fclose(fd);
            $display("[GEN_TOP] Wrote %s (seed=%0d, N_pay=%0d, cfo=%0d, tau=%0d, mod=%0d, cyc=%0d)",
                     fname, cfg.seed, cfg.N_payload, cfg.cfo_q24, cfg.tau_q16, cfg.init_mod, total_cycles);
        end
    end
endmodule
