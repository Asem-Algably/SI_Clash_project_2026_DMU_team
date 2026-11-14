// ============================================================================
// File Name   : wrapper_fsm.sv
// Module Name : wrapper_fsm
// Project     : SI-CLASH Real-Time Digital Synchronizer
// Description : Top-Level Synchronizer Burst FSM, Idle Watchdog & Flush Controller.
//
// 7-State FSM:
//   0: WAIT_BURST - Idle, waiting for first valid input sample
//   1: ACQUIRE    - STR settling during Phase A1
//   2: COARSE_EST - Coarse CFO correlation window & CORDIC angle calculation
//   3: LOAD       - Coarse word loaded into derotator
//   4: COSTAS_ACQ - Costas acquisition & quadrant resolution (Phase B & C)
//   5: TRACK      - Steady-state payload tracking
//   6: FLUSH      - Draining in-flight pipeline symbols for F clock cycles
//
// Idle Watchdog:
//   Monitors in_sample_valid_i during active burst states (1 through 5).
//   Triggers state FLUSH if idle_count reaches IDLE_TIMEOUT (default 14).
//
// Flush Drain:
//   Asserts flush_active_o for FLUSH_CLOCKS (default 15) cycles to drain
//   pipelines, then asserts a 1-cycle soft reset pulse flush_rst_o to re-arm.
// ============================================================================

module wrapper_fsm #(
    parameter int PREAMBLE_N_A    = 70,   // STR Phase A1 symbol budget
    parameter int PREAMBLE_TOTAL  = 190,  // Total preamble symbols (Phase A1+A2+B+C)
    parameter int IDLE_TIMEOUT    = 14,   // Consecutive invalid clocks before FLUSH
    parameter int FLUSH_CLOCKS    = 15,   // Pipeline drain clocks F = sps + lat.str + lat.derot + lat.wrap + margin
    parameter int PE_PIPE_DEPTH   = 3     // Latency pipeline for preamble_end pulse (derot + 1)
)(
    input  logic        clk_i,
    input  logic        rst_ni,

    // Datapath Valid & Status Inputs
    input  logic        in_sample_valid_i,
    input  logic        str_valid_i,
    input  logic        str_lock_i,
    input  logic        coarse_valid_i,
    input  logic        costas_lock_i,

    // Subsystem Control Outputs
    output logic        coarse_start_o,
    output logic [1:0]  costas_mode_o,   // 00 HOLD, 01 ACQ, 10 TRACK
    output logic        slicer_qpsk_o,   // 1 in preamble, 0 in payload
    output logic        preamble_end_o,  // Aligned pulse to Costas quad check
    output logic [2:0]  fsm_state_o,     // Current FSM state
    output logic        flush_active_o,  // 1 during FLUSH state
    output logic        flush_rst_o,     // 1-cycle soft reset pulse after FLUSH drain
    output logic [15:0] sym_cnt_o,       // Symbol counter
    output logic [7:0]  valid_during_flush_o // Diagnostic counter
);

    // State Encodings
    typedef enum logic [2:0] {
        ST_WAIT_BURST = 3'd0,
        ST_ACQUIRE    = 3'd1,
        ST_COARSE_EST = 3'd2,
        ST_LOAD       = 3'd3,
        ST_COSTAS_ACQ = 3'd4,
        ST_TRACK      = 3'd5,
        ST_FLUSH      = 3'd6
    } state_t;

    state_t state_q, state_d;

    // Counters and Registers
    logic [15:0] sym_cnt_q;
    logic [7:0]  idle_cnt_q;
    logic [7:0]  flush_cnt_q;
    logic [7:0]  flush_drop_cnt_q;
    logic        coarse_start_q;
    logic        flush_rst_q;
    logic [PE_PIPE_DEPTH-1:0] pe_pipe_q;

    // =========================================================================
    // 1. Symbol Counter & Preamble Pipeline
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            sym_cnt_q <= '0;
        end else if (state_q == ST_WAIT_BURST) begin
            sym_cnt_q <= '0;
        end else if (str_valid_i) begin
            sym_cnt_q <= sym_cnt_q + 1'b1;
        end
    end

    assign sym_cnt_o = sym_cnt_q;

    // =========================================================================
    // 2. FSM State Transition & Watchdog Logic
    // =========================================================================
    logic new_coarse_start;
    logic new_preamble_end;

    always_comb begin
        state_d          = state_q;
        new_coarse_start = 1'b0;
        new_preamble_end = 1'b0;

        case (state_q)
            ST_WAIT_BURST: begin
                if (in_sample_valid_i) begin
                    state_d = ST_ACQUIRE;
                end
            end

            ST_ACQUIRE: begin
                // Advance to Coarse CFO when STR locks or timeout expires
                if (str_valid_i) begin
                    if (str_lock_i || (sym_cnt_q >= PREAMBLE_N_A)) begin
                        state_d          = ST_COARSE_EST;
                        new_coarse_start = 1'b1;
                    end
                end
            end

            ST_COARSE_EST: begin
                // Wait for coarse CORDIC done pulse
                if (coarse_valid_i) begin
                    state_d = ST_LOAD;
                end
            end

            ST_LOAD: begin
                // Advance on next STR symbol strobe to align derotator
                if (str_valid_i) begin
                    state_d = ST_COSTAS_ACQ;
                end
            end

            ST_COSTAS_ACQ: begin
                // Advance to TRACK when total preamble duration finishes
                if (str_valid_i && (sym_cnt_q >= PREAMBLE_TOTAL)) begin
                    state_d          = ST_TRACK;
                    new_preamble_end = 1'b1;
                end
            end

            ST_TRACK: begin
                // Normal payload tracking; remains here until watchdog timeout
            end

            ST_FLUSH: begin
                // Draining in-flight symbols for FLUSH_CLOCKS
                if (flush_cnt_q >= (FLUSH_CLOCKS - 1)) begin
                    state_d = ST_WAIT_BURST;
                end
            end

            default: begin
                state_d = ST_WAIT_BURST;
            end
        endcase

        // Always-on Idle Watchdog: overrides state if consecutive invalid clocks >= IDLE_TIMEOUT
        if ((state_q >= ST_ACQUIRE) && (state_q <= ST_TRACK)) begin
            if (!in_sample_valid_i && (idle_cnt_q >= (IDLE_TIMEOUT - 1))) begin
                state_d = ST_FLUSH;
            end
        end
    end

    // =========================================================================
    // 3. Sequential Control Registers
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q          <= ST_WAIT_BURST;
            idle_cnt_q       <= '0;
            flush_cnt_q      <= '0;
            flush_drop_cnt_q <= '0;
            coarse_start_q   <= 1'b0;
            flush_rst_q      <= 1'b0;
            pe_pipe_q        <= '0;
        end else begin
            state_q        <= state_d;
            coarse_start_q <= new_coarse_start;

            // Preamble-end alignment pipeline
            pe_pipe_q <= {pe_pipe_q[PE_PIPE_DEPTH-2:0], new_preamble_end};

            // Watchdog Counter
            if (state_q == ST_WAIT_BURST || in_sample_valid_i) begin
                idle_cnt_q <= '0;
            end else if ((state_q >= ST_ACQUIRE) && (state_q <= ST_TRACK)) begin
                if (!in_sample_valid_i) begin
                    idle_cnt_q <= idle_cnt_q + 1'b1;
                end
            end

            // Flush Drain Counter & Soft-Reset Generation
            if (state_q == ST_FLUSH) begin
                flush_cnt_q <= flush_cnt_q + 1'b1;
                if (in_sample_valid_i) begin
                    flush_drop_cnt_q <= flush_drop_cnt_q + 1'b1;
                end
                if (flush_cnt_q >= (FLUSH_CLOCKS - 1)) begin
                    flush_rst_q <= 1'b1; // 1-cycle soft reset pulse
                    flush_cnt_q <= '0;
                end else begin
                    flush_rst_q <= 1'b0;
                end
            end else begin
                flush_cnt_q <= '0;
                flush_rst_q <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. Output Assignments
    // =========================================================================
    assign fsm_state_o          = state_q;
    assign coarse_start_o       = (state_q == ST_COARSE_EST);
    assign preamble_end_o       = pe_pipe_q[PE_PIPE_DEPTH-1];
    assign flush_active_o       = (state_q == ST_FLUSH);
    assign flush_rst_o          = flush_rst_q;
    assign valid_during_flush_o = flush_drop_cnt_q;

    // Costas mode: 00 HOLD, 01 ACQ, 10 TRACK
    always_comb begin
        case (state_q)
            ST_COSTAS_ACQ: costas_mode_o = 2'b01; // ACQ
            ST_TRACK:      costas_mode_o = 2'b10; // TRACK
            default:       costas_mode_o = 2'b00; // HOLD
        endcase
    end

    // Slicer QPSK force: 1 in all states except TRACK
    assign slicer_qpsk_o = (state_q != ST_TRACK);

endmodule
