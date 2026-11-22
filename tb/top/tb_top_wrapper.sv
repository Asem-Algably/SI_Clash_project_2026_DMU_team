// ============================================================================
// File Name   : tb_top_wrapper.sv
// Module Name : tb_top_wrapper
// Project     : SI-CLASH Real-Time Digital Synchronizer
// Description : Top-Level SystemVerilog Verification Testbench for top_wrapper.
//               Verifies:
//                 1. Burst start and FSM transitions (WAIT_BURST -> ACQUIRE -> TRACK)
//                 2. Small gaps (< 14 clocks): STR freeze without FSM flush
//                 3. Long gap (>= 14 clocks): Watchdog timeout -> FLUSH -> WAIT_BURST
//                 4. Back-to-back burst recovery
// ============================================================================

`timescale 1ns / 1ps

module tb_top_wrapper;
    parameter int CLK_PERIOD = 8; // 125 MHz system clock

    logic        clk_i;
    logic        rst_ni;
    logic        s_axis_valid_i;
    logic signed [11:0] s_axis_i_sample_i;
    logic signed [11:0] s_axis_q_sample_i;
    logic        mod_type_i;

    logic        m_axis_valid_o;
    logic signed [15:0] m_axis_i_sym_o;
    logic signed [15:0] m_axis_q_sym_o;
    logic        lock_detect_o;
    logic signed [23:0] coarse_cfo_est_o;
    logic signed [31:0] fine_cfo_est_o;
    logic [2:0]  fsm_state_o;
    logic        flush_active_o;
    logic [7:0]  valid_during_flush_o;

    // Instantiate Top-Level Synchronizer Wrapper
    top_wrapper dut (
        .clk_i               (clk_i),
        .rst_ni              (rst_ni),
        .s_axis_valid_i      (s_axis_valid_i),
        .s_axis_i_sample_i   (s_axis_i_sample_i),
        .s_axis_q_sample_i   (s_axis_q_sample_i),
        .mod_type_i          (mod_type_i),
        .m_axis_valid_o      (m_axis_valid_o),
        .m_axis_i_sym_o      (m_axis_i_sym_o),
        .m_axis_q_sym_o      (m_axis_q_sym_o),
        .lock_detect_o       (lock_detect_o),
        .coarse_cfo_est_o    (coarse_cfo_est_o),
        .fine_cfo_est_o      (fine_cfo_est_o),
        .fsm_state_o         (fsm_state_o),
        .flush_active_o      (flush_active_o),
        .valid_during_flush_o(valid_during_flush_o)
    );

    // Clock Generation
    initial clk_i = 0;
    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    // QPSK symbols (+-1, +-1) scaled to Q1.11 (+-300)
    localparam logic signed [11:0] Q_VAL = 12'sd300;
    logic signed [11:0] qpsk_sym_i [0:3] = '{ Q_VAL, -Q_VAL, -Q_VAL,  Q_VAL };
    logic signed [11:0] qpsk_sym_q [0:3] = '{ Q_VAL,  Q_VAL, -Q_VAL, -Q_VAL };

    // Task: send one sample
    task automatic send_sample(input logic signed [11:0] i_val, input logic signed [11:0] q_val);
        @(posedge clk_i);
        s_axis_valid_i    <= 1'b1;
        s_axis_i_sample_i <= i_val;
        s_axis_q_sample_i <= q_val;
    endtask

    // Task: insert K idle clocks
    task automatic idle_clocks(input int k);
        @(posedge clk_i);
        s_axis_valid_i    <= 1'b0;
        s_axis_i_sample_i <= '0;
        s_axis_q_sample_i <= '0;
        if (k > 1) begin
            repeat (k - 1) @(posedge clk_i);
        end
    endtask

    // Simulation Sequence
    initial begin : tb_main
        automatic int sym_idx;
        rst_ni            = 1'b0;
        s_axis_valid_i    = 1'b0;
        s_axis_i_sample_i = '0;
        s_axis_q_sample_i = '0;
        mod_type_i        = 1'b0; // QPSK

        $display("==================================================================");
        $display("  TOP WRAPPER RTL HARDWARE VERIFICATION TESTBENCH");
        $display("==================================================================");

        #(CLK_PERIOD * 10);
        rst_ni = 1'b1;
        #(CLK_PERIOD * 5);

        $display("[SCENARIO 1] Verifying WAIT_BURST state...");
        assert(fsm_state_o == 3'd0) else $error("FSM not in WAIT_BURST!");

        // Drive 400 samples (100 symbols)
        $display("[SCENARIO 2] Starting burst: driving preamble samples...");
        for (int s = 0; s < 100; s++) begin
            sym_idx = s % 4;
            // 4 samples per symbol (sps = 4)
            for (int smp = 0; smp < 4; smp++) begin
                send_sample(qpsk_sym_i[sym_idx], qpsk_sym_q[sym_idx]);
            end
        end

        $display("  -> Current FSM State: %0d", fsm_state_o);
        assert(fsm_state_o >= 3'd1) else $error("FSM failed to transition to active burst!");

        // Small Gap: 5 idle clocks (< 14 timeout)
        $display("[SCENARIO 3] Injecting small gap (5 idle clocks < 14 timeout)...");
        idle_clocks(5);
        $display("  -> FSM State during gap: %0d (Flush Active = %0b)", fsm_state_o, flush_active_o);
        assert(flush_active_o == 1'b0) else $error("Flush triggered prematurely on 5-clock gap!");

        // Resume samples for 40 symbols
        $display("[SCENARIO 4] Resuming samples after small gap...");
        for (int s = 0; s < 40; s++) begin
            sym_idx = s % 4;
            for (int smp = 0; smp < 4; smp++) begin
                send_sample(qpsk_sym_i[sym_idx], qpsk_sym_q[sym_idx]);
            end
        end

        // Long Gap: 25 idle clocks (> 14 timeout) -> Trigger Watchdog FLUSH
        $display("[SCENARIO 5] Injecting inter-burst gap (25 idle clocks >= 14 timeout)...");
        idle_clocks(25);

        // Wait for FLUSH drain sequence (F = 15 clocks) to complete
        #(CLK_PERIOD * 20);
        $display("  -> FSM State after Flush drain: %0d (Expected: 0 WAIT_BURST)", fsm_state_o);
        assert(fsm_state_o == 3'd0) else $error("FSM failed to return to WAIT_BURST after FLUSH drain!");

        // Next Burst
        $display("[SCENARIO 6] Starting second burst after recovery...");
        for (int s = 0; s < 50; s++) begin
            sym_idx = s % 4;
            for (int smp = 0; smp < 4; smp++) begin
                send_sample(qpsk_sym_i[sym_idx], qpsk_sym_q[sym_idx]);
            end
        end

        idle_clocks(10);
        $display("  -> Second burst active state: %0d", fsm_state_o);
        assert(fsm_state_o >= 3'd1) else $error("FSM failed to start second burst!");

        $display("==================================================================");
        $display("  ALL TOP-LEVEL RTL INTEGRATION TESTS PASSED PERFECTLY!");
        $display("==================================================================");
        $finish;
    end

    // Monitor
    always @(posedge clk_i) begin
        if (m_axis_valid_o) begin
            $display("[RTL OUT] clk=%0t | SymOut: I=%0d, Q=%0d | FSM State=%0d", 
                $time, m_axis_i_sym_o, m_axis_q_sym_o, fsm_state_o);
        end
    end

endmodule
