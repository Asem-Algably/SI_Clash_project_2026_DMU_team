// Standalone Constrained-Random Scenario Generator for costas_top
// Combines full-chain bursts (gen_mode=0) and standalone Costas unit cases (gen_mode=1)
// targeting 100% across all 8 costas_pkg covergroups + PI saturation / lock drop branches.
module gen_costas_cases;

    class costas_cfg;
        rand bit [31:0] seed;
        rand int        N_payload;
        rand int        snr_x100;
        rand int        cfo_q24;
        rand int        tau_q16;
        rand int        phase_q24;
        int             gen_mode;
        int             corner_tag;
        int             target_quad = -1; // 0..3 -> k0..k3

        constraint c_seed { seed != 32'd0; }
        constraint c_len  { N_payload inside {[160 : 220]}; }
        constraint c_snr  { snr_x100 inside {[1200 : 2500]}; }
        constraint c_tau  { tau_q16 inside {[0 : 65535]}; }
        constraint c_cfo  { cfo_q24 inside {[-1342177 : 1342177]}; }
        constraint c_ph {
            if (target_quad == 0)      phase_q24 inside {[-500000 : 500000]};      // near 0 deg (k0)
            else if (target_quad == 1) phase_q24 inside {[3694304 : 4694304]};    // near +90 deg (k1)
            else if (target_quad == 2) phase_q24 inside {[7888607 : 8388607]};    // near +180 deg (k2)
            else if (target_quad == 3) phase_q24 inside {[-4694304 : -3694304]};  // near -90 deg (k3)
            else                       phase_q24 inside {[-8388608 : 8388607]};
        }
    endclass

    class costas_cyc;
        rand bit s_valid;
        constraint c_v { s_valid dist {1 := 85, 0 := 15}; }
    endclass

    initial begin
        int        fd, num_cases;
        costas_cfg cfg;
        costas_cyc cyc;
        bit        rst_n, s_val, pe, sl_qpsk;
        bit [1:0]  mode_i, mod_i;
        int        total_cycles;
        string     fname;

        num_cases = 11;
        void'($system("if not exist cases mkdir cases"));
        cfg = new();
        cyc = new();

        for (int c = 1; c <= num_cases; c++) begin
            cfg.target_quad = -1;
            if (c <= 2) begin
                cfg.gen_mode   = 0;
                cfg.corner_tag = 0;
            end else begin
                cfg.gen_mode = 1;
                if (c >= 3 && c <= 6) begin
                    cfg.corner_tag  = 3; // Quad sweep k0..k3 x {counter_full, preamble_end}
                    cfg.target_quad = c - 3;
                end else if (c == 7) begin
                    cfg.corner_tag  = 4; // quad_unresolved
                end else if (c == 8) begin
                    cfg.corner_tag  = 5; // PI pos_high & neg_high saturation + large errors
                end else if (c == 9) begin
                    cfg.corner_tag  = 6; // Lock loss <fall, done, ok> + 16-QAM constellation
                end else if (c == 10) begin
                    cfg.corner_tag  = 7; // Randomized 16-QAM/QPSK + long gaps + mid-burst resets
                end else begin
                    cfg.corner_tag  = 8; // u_lock_int bucket >= 2 unlock decrement before done
                end
            end

            if (!cfg.randomize()) $fatal(1, "Randomization failed on costas cfg");
            total_cycles = (cfg.gen_mode == 0) ? ((190 + cfg.N_payload) * 4 + 40) : 340;

            fname = $sformatf("cases/cfg_tc_%02d.txt", c);
            fd = $fopen(fname, "w");
            if (fd == 0) $fatal(1, "Could not open %s", fname);

            $fwrite(fd, "# MODULE costas CASE %02d\n", c);
            $fwrite(fd, "CFG %0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
                    cfg.seed, cfg.gen_mode, cfg.corner_tag, cfg.N_payload,
                    cfg.snr_x100, cfg.cfo_q24, cfg.tau_q16, cfg.phase_q24, total_cycles);

            for (int t = 0; t < total_cycles; t++) begin
                if (!cyc.randomize()) $fatal(1, "Randomization failed on costas mask");
                rst_n   = 1'b1;
                pe      = 1'b0;
                s_val   = 1'b0;
                mode_i  = 2'b00; // HOLD
                mod_i   = 2'b00; // QPSK

                if (cfg.gen_mode == 0) begin
                    // Full-chain: cycle valid mask + runtime mod_type switching
                    s_val = (t < total_cycles - 40) ? (t < 8 ? 1'b1 : cyc.s_valid) : 1'b0;
                    // Hold long 3+ invalid gaps near mid-burst to ensure 0[*3] hit
                    if (t >= 200 && t <= 204) s_val = 1'b0;
                    mod_i = (c == 1) ? ((t > 900 && t < 1100) ? 2'b01 : 2'b00)
                                     : ((t > 950 && t < 1150) ? 2'b00 : 2'b01);
                    mode_i = 2'b01; // placeholder; MATLAB wrapper FSM overrides in gen_mode=0
                    sl_qpsk = 1'b1;
                end else if (cfg.corner_tag == 3) begin
                    // Two standalone bursts:
                    // Burst A (t=4..169): counter_full trigger (pe=0 during cnt saturation)
                    // Gap     (t=170..177): HOLD -> reset lock/quad for Burst B
                    // Burst B (t=178..330): preamble_end trigger right at sym 21 (after lock_int locks @12, before cnt==15)
                    mod_i = (c == 3 || c == 5) ? 2'b00 : 2'b01; // QPSK & QAM16 TRACK coverage
                    if (t < 4) begin
                        mode_i = 2'b00; s_val = 1'b0;
                    end else if (t < 100) begin
                        mode_i = 2'b01; // ACQ: 96 continuous valid cycles (~28 syms -> hits CNT_MAX=15 cleanly inside ACQ)
                        s_val  = 1'b1;
                    end else if (t < 168) begin
                        mode_i = 2'b10; // TRACK
                        s_val  = cyc.s_valid;
                    end else if (t < 176) begin
                        mode_i = 2'b00; // HOLD (hits TRACK => HOLD and HOLD => ACQ next)
                        s_val  = 1'b0;
                    end else if (t < 236) begin
                        mode_i = 2'b01; // ACQ Burst B: continuous valid so lock_int asserts ~t=199 & |cnt|~9..12 before t=212
                        s_val  = (t < 220 || t > 224); // includes 0[*3] gap around 220..224
                        if (t == 212) pe = 1'b1; // Pulse preamble_end while 0 < |cnt| < 15 -> by_preamble_end!
                    end else if (t < 332) begin
                        mode_i = 2'b10; // TRACK
                        s_val  = (t < 250) ? 1'b1 : cyc.s_valid;
                    end else begin
                        mode_i = 2'b00; s_val = 1'b0;
                    end
                end else if (cfg.corner_tag == 4) begin
                    // quad_unresolved: sps=4 spacing in ACQ avoids sgn_i_pos_q 1-stage skew; sym 34 at t=136 lands on cnt=0 before pe=1 at t=140
                    mod_i = 2'b01;
                    if (t < 4) begin
                        mode_i = 2'b00; s_val = 1'b0;
                    end else if (t < 144) begin
                        mode_i = 2'b01;
                        s_val  = (t < 140) && ((t % 4) == 0);
                        if (t == 140) pe = 1'b1;
                    end else if (t < 240) begin
                        mode_i = 2'b10; s_val = 1'b1;
                    end else begin
                        mode_i = 2'b00; s_val = 1'b0;
                    end
                end else if (cfg.corner_tag == 5) begin
                    // PI pos_high & neg_high saturation + large pos/neg errors
                    // Window 1 (ACQ, QPSK, then TRACK QAM16): sustained pos error -> pos_high int & freq
                    // Window 2 (after HOLD): sustained neg error -> neg_high int & freq
                    mod_i = 2'b01;
                    if (t < 4)        begin mode_i = 2'b00; s_val = 1'b0; end
                    else if (t < 90)  begin mode_i = 2'b01; s_val = 1'b1; pe = (t == 50); end
                    else if (t < 165) begin mode_i = 2'b10; s_val = 1'b1; end
                    else if (t < 175) begin mode_i = 2'b00; s_val = 1'b0; end
                    else if (t < 255) begin mode_i = 2'b01; s_val = 1'b1; pe = (t == 215); end
                    else if (t < 332) begin mode_i = 2'b10; s_val = 1'b1; end
                    else              begin mode_i = 2'b00; s_val = 1'b0; end
                end else if (cfg.corner_tag == 6) begin
                    // Lock drop <fall, done, ok> + all 16-QAM constellation points in TRACK
                    mod_i = 2'b01;
                    if (t < 4)        begin mode_i = 2'b00; s_val = 1'b0; end
                    else if (t < 60)  begin mode_i = 2'b01; s_val = 1'b1; pe = (t == 45); end
                    else if (t < 330) begin mode_i = 2'b10; s_val = 1'b1; end
                    else              begin mode_i = 2'b00; s_val = 1'b0; end
                end else if (cfg.corner_tag == 7) begin
                    // corner_tag == 7: Randomized 16-QAM constellation + zero error + long gaps + 2 active resets!
                    mod_i = 2'b01;
                    if (t < 4)        begin mode_i = 2'b00; s_val = 1'b0; end
                    else if (t < 55)  begin mode_i = 2'b01; s_val = (t >= 20 && t <= 24) ? 1'b0 : 1'b1; pe = (t == 42); end
                    else if (t < 180) begin mode_i = 2'b10; s_val = cyc.s_valid; end
                    else if (t < 185) begin rst_n  = 1'b0;  mode_i = 2'b00; s_val = 1'b0; end // reset #1
                    else if (t < 235) begin mode_i = 2'b01; s_val = 1'b1; pe = (t == 220); end
                    else if (t < 240) begin rst_n  = 1'b0;  mode_i = 2'b00; s_val = 1'b0; end // reset #2 in ACQ->TRACK transition
                    else if (t < 330) begin mode_i = 2'b10; s_val = 1'b1; end
                    else              begin mode_i = 2'b00; s_val = 1'b0; end
                end else begin
                    // corner_tag == 8: Charge u_lock_int bucket >= 2 during ACQ while !done, then inject high phase error
                    mod_i = 2'b00;
                    if (t < 4)        begin mode_i = 2'b00; s_val = 1'b0; end
                    else if (t < 140) begin mode_i = 2'b01; s_val = 1'b1; pe = (t == 135); end
                    else if (t < 330) begin mode_i = 2'b10; s_val = 1'b1; end
                    else              begin mode_i = 2'b00; s_val = 1'b0; end
                end

                // Maintain architectural invariant slicer_qpsk == (mode != TRACK)
                sl_qpsk = (mode_i != 2'b10);

                $fwrite(fd, "%0d %0d %0d %0d %0d %0d\n", rst_n, s_val, mode_i, pe, mod_i, sl_qpsk);
            end
            $fclose(fd);
            $display("[GEN_COSTAS] Wrote %s (mode=%0d, corner=%0d, seed=%0d, ph=%0d)",
                     fname, cfg.gen_mode, cfg.corner_tag, cfg.seed, cfg.phase_q24);
        end
    end
endmodule
