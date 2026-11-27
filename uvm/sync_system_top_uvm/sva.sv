module sva (
    input logic               clk,
    input logic               rst_n,
    input logic               rst_n_eff,
    input logic               in_sample_valid,
    input logic               out_sym_valid,
    input logic signed [15:0] out_sym_i,
    input logic signed [15:0] out_sym_q,
    input logic               lock_detect,
    input logic               str_lock,
    input logic               costas_lock,
    input logic               flush_active,
    input logic [2:0]         fsm_state,
    input logic [3:0]         dft_sel,
    input logic [31:0]        dft_obs_data,
    input logic               force_w_en,
    input logic [15:0]        force_w,
    input logic               force_cfo_en,
    input logic signed [23:0] force_cfo,
    input logic               force_freq_en,
    input logic [31:0]        force_freq,
    input logic signed [31:0] ted_err_aligned,
    input logic [9:0]         str_mu,
    input logic [15:0]        str_w,
    input logic signed [15:0] str_sym_i,
    input logic signed [23:0] coarse_est,
    input logic signed [15:0] costas_err_aligned,
    input logic [31:0]        nco_freq_word,
    input logic [31:0]        nco_phase,
    input logic signed [15:0] derot_sym_i,
    input logic signed [31:0] costas_int,
    input logic [31:0]        costas_phase_adj,
    input logic signed [31:0] costas_freq_adj,
    input logic               str_valid,
    input logic               str_ce,
    input logic [23:0]        str_nco_m_q,
    input logic signed [31:0] derot_coarse_reg,
    input logic signed [31:0] derot_freq_word_o
);

    // Expected 16 DFT observation channels matching sync_system_top.sv
    logic [31:0] exp_dft_ch [0:15];
    always_comb begin
        exp_dft_ch[0]  = 32'($signed(ted_err_aligned));
        exp_dft_ch[1]  = 32'(str_mu);
        exp_dft_ch[2]  = 32'(str_w);
        exp_dft_ch[3]  = 32'($signed(str_sym_i));
        exp_dft_ch[4]  = 32'($signed(coarse_est));
        exp_dft_ch[5]  = 32'($signed(costas_err_aligned));
        exp_dft_ch[6]  = 32'($signed(nco_freq_word));
        exp_dft_ch[7]  = 32'(nco_phase);
        exp_dft_ch[8]  = 32'($signed(derot_sym_i));
        exp_dft_ch[9]  = 32'($signed(costas_int));
        exp_dft_ch[10] = 32'(costas_phase_adj);
        exp_dft_ch[11] = 32'($signed(costas_freq_adj));
        exp_dft_ch[12] = 32'(str_lock);
        exp_dft_ch[13] = 32'(costas_lock);
        exp_dft_ch[14] = 32'(fsm_state);
        exp_dft_ch[15] = 32'(str_valid);
    end

    // 1. Reset forces the burst FSM back to WaitBurst
    a_reset_state: assert property (@(posedge clk) !rst_n |=> fsm_state == 3'd0)
        else $error("[SVA] FSM not in WaitBurst after reset");

    // 2. FSM state is always one of the 7 legal states
    a_legal_state: assert property (@(posedge clk) disable iff (!rst_n) fsm_state <= 3'd6)
        else $error("[SVA] illegal FSM state %0d", fsm_state);

    // 3. flush_active is exactly the Flush state
    a_flush_state: assert property (@(posedge clk) disable iff (!rst_n) flush_active == (fsm_state == 3'd6))
        else $error("[SVA] flush_active does not match FSM Flush state");

    // 4. Public lock is the AND of the STR and Costas locks
    a_lock_and: assert property (@(posedge clk) disable iff (!rst_n) lock_detect == (str_lock & costas_lock))
        else $error("[SVA] lock_detect != str_lock & costas_lock");

    // 5. Output symbols are never X/Z when valid
    a_no_x_out: assert property (@(posedge clk) disable iff (!rst_n)
                                 out_sym_valid |-> !$isunknown({out_sym_i, out_sym_q}))
        else $error("[SVA] out_sym is X while out_sym_valid is high");

    // 6. Control inputs are never X/Z after reset
    a_no_x_in: assert property (@(posedge clk) disable iff (!rst_n)
                                !$isunknown(in_sample_valid))
        else $error("[SVA] in_sample_valid is X");

    // 7. Outputs only appear once the burst reached CostasAcq (derotator input is gated by
    //    state >= 4); the pipeline may still drain in the first cycle after Flush
    a_out_after_acq: assert property (@(posedge clk) disable iff (!rst_n)
                                      out_sym_valid |-> (fsm_state >= 3'd4) || ($past(fsm_state) == 3'd6))
        else $error("[SVA] out_sym_valid asserted before CostasAcq");

    // 8. Idle watchdog: 14 consecutive invalid clocks in an active state force the Flush state
    a_watchdog: assert property (@(posedge clk) disable iff (!rst_n)
                                 ((fsm_state >= 3'd1 && fsm_state <= 3'd5 && !in_sample_valid) [*14]) |=> flush_active)
        else $error("[SVA] idle watchdog did not trigger Flush");

    // 9. A burst can only leave WaitBurst on a valid sample
    a_start: assert property (@(posedge clk) disable iff (!rst_n)
                              (fsm_state == 3'd0 && $past(fsm_state) == 3'd0 && !in_sample_valid)
                              |=> fsm_state == 3'd0)
        else $error("[SVA] FSM left WaitBurst without in_sample_valid");

    // 10. All 16 DFT observation channels match internal DUT probes on every active cycle
    a_dft_mux_exact: assert property (@(posedge clk) disable iff (!rst_n)
                                      (!$isunknown(dft_sel)) |-> (dft_obs_data === exp_dft_ch[dft_sel]))
        else $error("[SVA] dft_obs_data mismatch on ch %0d: got=%08h exp=%08h",
                    dft_sel, dft_obs_data, exp_dft_ch[dft_sel]);

    // 11. STR force_w overrides actual modulo-1 NCO phase decrement
    a_force_w_nco: assert property (@(posedge clk) disable iff (!rst_n || !rst_n_eff)
                                    (str_ce && force_w_en) |=> (str_nco_m_q === ($past(str_nco_m_q) - {$past(force_w), 8'd0})))
        else $error("[SVA] STR modulo_1_controller.m_q did not step by force_w");

    // 12. Coarse CFO force_cfo updates BOTH coarse_cfo_core and derotator coarse_reg
    a_force_cfo_core: assert property (@(posedge clk) disable iff (!rst_n || !rst_n_eff)
                                       force_cfo_en |=> (coarse_est === $past(force_cfo)))
        else $error("[SVA] coarse_est did not capture force_cfo");

    a_force_cfo_derot: assert property (@(posedge clk) disable iff (!rst_n || !rst_n_eff)
                                        force_cfo_en |-> ##2 (derot_coarse_reg === {$past(force_cfo, 2), 8'd0}))
        else $error("[SVA] Derotator coarse_reg did not update from force_cfo");

    // 13. Derotator force_freq overrides frequency control word register
    a_force_freq_word: assert property (@(posedge clk) disable iff (!rst_n || !rst_n_eff)
                                        force_freq_en |=> (derot_freq_word_o === $past(force_freq)))
        else $error("[SVA] Derotator freq_word_o did not track force_freq");

    // ---------------- cover properties ----------------
    c_full_burst: cover property (@(posedge clk) fsm_state == 3'd5 ##[1:$] fsm_state == 3'd6 ##[1:$] fsm_state == 3'd0);
    c_lock:       cover property (@(posedge clk) lock_detect);
    c_out_valid:  cover property (@(posedge clk) out_sym_valid);
endmodule
