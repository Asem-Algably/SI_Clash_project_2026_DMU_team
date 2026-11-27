module sva (
    input logic               clk,
    input logic               rst_n,
    input logic               in_sample_valid,
    input logic               out_sym_valid,
    input logic signed [15:0] out_sym_i,
    input logic signed [15:0] out_sym_q,
    input logic               lock_detect,
    input logic               str_lock,
    input logic               costas_lock,
    input logic               flush_active,
    input logic [2:0]         fsm_state
);

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

    // ---------------- cover properties ----------------
    c_full_burst: cover property (@(posedge clk) fsm_state == 3'd5 ##[1:$] fsm_state == 3'd6 ##[1:$] fsm_state == 3'd0);
    c_lock:       cover property (@(posedge clk) lock_detect);
    c_out_valid:  cover property (@(posedge clk) out_sym_valid);
endmodule
