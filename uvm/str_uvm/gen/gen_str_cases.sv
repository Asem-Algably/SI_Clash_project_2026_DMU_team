// Standalone Constrained-Random Scenario Generator for str_top
// tau_offset is randomized once per burst; only pin masks & PRNG seed are emitted.
module gen_str_cases;

    class str_burst_cfg;
        rand bit [31:0] seed;
        rand int        N_payload;
        rand int        snr_x100;
        rand int        cfo_q24;
        rand int        tau_q16;
        rand bit [1:0]  mod_type;
        bit [1:0]       tau_quad;
        bit             do_force;
        bit             do_reset;

        constraint c_seed { seed != 32'd0; }
        constraint c_len  { N_payload inside {[180 : 250]}; }
        constraint c_snr  { snr_x100 dist {[1000:1400] := 25, [1401:2200] := 50, [2201:2800] := 25}; }
        constraint c_cfo  { cfo_q24 inside {[-1342177 : 1342177]}; } // [-0.08, +0.08]
        constraint c_mod  { mod_type inside {2'b00, 2'b01}; }
        constraint c_tau  {
            if (tau_quad == 0)      tau_q16 inside {[0     : 16383]};
            else if (tau_quad == 1) tau_q16 inside {[16384 : 32767]};
            else if (tau_quad == 2) tau_q16 inside {[32768 : 49151]};
            else                    tau_q16 inside {[49152 : 65535]};
        }
    endclass

    class str_cyc_mask;
        rand bit          in_val;
        rand bit          force_w_en;
        rand logic [15:0] force_w;
        constraint c_v { in_val dist {1 := 93, 0 := 7}; }
        constraint c_f {
            force_w_en dist {0 := 94, 1 := 6};
            force_w inside {[16'h3400 : 16'h4C00]};
        }
    endclass

    initial begin
        int           fd, num_cases;
        str_burst_cfg cfg;
        str_cyc_mask  cyc;
        bit           rst_n, in_val, flush_act, fw_en;
        int           rx_len, total_cycles, reset_clk;
        string        fname;

        num_cases = 8;
        void'($system("if not exist cases mkdir cases"));
        cfg = new();
        cyc = new();

        for (int c = 1; c <= num_cases; c++) begin
            cfg.tau_quad = (c - 1) % 4; // Cover all 4 mu/tau quadrants across 8 randomized bursts
            if (!cfg.randomize()) $fatal(1, "Randomization failed on str cfg");
            cfg.do_force = (c == 3 || c == 6);
            cfg.do_reset = (c == 7 || c == 8); // 2 active mid-burst reset cases

            rx_len       = (190 + cfg.N_payload) * 4;
            total_cycles = rx_len + 24;
            reset_clk    = (c == 7) ? 180 : 850;

            fname = $sformatf("cases/cfg_tc_%02d.txt", c);
            fd = $fopen(fname, "w");
            if (fd == 0) $fatal(1, "Could not open %s", fname);

            $fwrite(fd, "# MODULE str CASE %02d\n", c);
            $fwrite(fd, "CFG %0d 0 0 %0d %0d %0d %0d 0 %0d\n",
                    cfg.seed, cfg.N_payload, cfg.snr_x100, cfg.cfo_q24, cfg.tau_q16, total_cycles);

            for (int t = 0; t < total_cycles; t++) begin
                if (!cyc.randomize()) $fatal(1, "Randomization failed on str mask");
                rst_n     = 1'b1;
                flush_act = (t >= rx_len) && (t < rx_len + 16);
                fw_en     = cfg.do_force && (t > 120 && t < rx_len) && cyc.force_w_en;

                if (cfg.do_reset && (t >= reset_clk && t < reset_clk + 3)) begin
                    rst_n     = 1'b0;
                    in_val    = 1'b0;
                    flush_act = 1'b0;
                end else if (t >= rx_len) begin
                    in_val = 1'b0;
                end else if (t < 8) begin
                    in_val = 1'b1;
                end else begin
                    in_val = cyc.in_val;
                end

                $fwrite(fd, "%0d %0d %0d %0d %04x\n", rst_n, in_val, flush_act, fw_en, cyc.force_w);
            end
            $fclose(fd);
            $display("[GEN_STR] Wrote %s (seed=%0d, tau=%0d, cfo=%0d, cyc=%0d)",
                     fname, cfg.seed, cfg.tau_q16, cfg.cfo_q24, total_cycles);
        end
    end
endmodule
