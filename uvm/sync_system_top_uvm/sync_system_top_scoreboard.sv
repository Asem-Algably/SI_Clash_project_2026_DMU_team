package sync_system_top_scoreborad_pck;
    import uvm_pkg::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"

    class sync_system_top_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(sync_system_top_scoreborad)

        uvm_analysis_export #(sync_system_top_seq_item)   sb_export;    // actual (monitor)
        uvm_analysis_export #(sync_system_top_seq_item)   exp_export;   // expected output symbols (driver)
        uvm_analysis_export #(sync_system_top_seq_item)   st_export;    // expected FSM state changes (driver)
        uvm_tlm_analysis_fifo #(sync_system_top_seq_item) sb_fifo;
        uvm_tlm_analysis_fifo #(sync_system_top_seq_item) exp_fifo;
        uvm_tlm_analysis_fifo #(sync_system_top_seq_item) st_fifo;

        // ---------------- knobs (set by the test) ----------------
        bit   enable_check   = 1'b1;     // test clears it for non-golden sequences
        bit   check_lock     = 1'b0;     // lock_detect vs golden is informational unless +CHECK_LOCK
        bit   check_cfo      = 1'b1;     // coarse CFO vs expected_metrics.txt
        int   exp_coarse_cfo = 1089400;  // expected_metrics.txt: coarse_cfo_stored
        int   max_err_msgs   = 20;

        // ---------------- counters ----------------
        int correct_count       = 0;
        int wrong_count         = 0;
        int extra_count         = 0;
        int strobe_count        = 0;
        int lock_mismatch_count = 0;
        int state_change_count  = 0;
        int state_err_count     = 0;
        int cfo_err_count       = 0;

        logic [2:0]          prev_state  = 3'd0;
        bit                  cfo_checked = 1'b0;
        bit                  last_lock   = 1'b0;
        logic signed [23:0]  cfo_golden;

        function new(string name = "sync_system_top_scoreborad", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sb_export  = new("sb_export",  this);
            exp_export = new("exp_export", this);
            st_export  = new("st_export",  this);
            sb_fifo    = new("sb_fifo",    this);
            exp_fifo   = new("exp_fifo",   this);
            st_fifo    = new("st_fifo",    this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
            exp_export.connect(exp_fifo.analysis_export);
            st_export.connect(st_fifo.analysis_export);
        endfunction

        function string st_name(logic [2:0] s);
            case (s)
                3'd0:    return "WaitBurst";
                3'd1:    return "Acquire";
                3'd2:    return "CoarseEst";
                3'd3:    return "Load";
                3'd4:    return "CostasAcq";
                3'd5:    return "Track";
                3'd6:    return "Flush";
                default: return "ILLEGAL";
            endcase
        endfunction

        task run_phase(uvm_phase phase);
            sync_system_top_seq_item actual;
            sync_system_top_seq_item expected;
            sync_system_top_seq_item exp_st;
            int                      diff_i, diff_q;
            logic signed [31:0]      cfo_ext;

            forever begin
                sb_fifo.get(actual);

                // ------------------------------------------------------------
                // 1) Burst FSM state sequence (latency independent: compares the
                //    ORDER of state changes against the golden file)
                // ------------------------------------------------------------
                if (!$isunknown(actual.fsm_state) && (actual.fsm_state !== prev_state)) begin
                    state_change_count++;
                    if (actual.fsm_state == 3'd0) begin
                        cfo_checked = 1'b0;
                    end
                    if (enable_check) begin
                        if (st_fifo.try_get(exp_st)) begin
                            if (exp_st.exp_state !== actual.fsm_state) begin
                                state_err_count++;
                                if (state_err_count <= max_err_msgs)
                                    `uvm_error("SB_STATE", $sformatf("State change %0d: RTL %s(%0d) -> expected %s(%0d)",
                                               state_change_count, st_name(actual.fsm_state), actual.fsm_state,
                                               st_name(exp_st.exp_state), exp_st.exp_state))
                            end
                        end else begin
                            exp_st = null;
                            state_err_count++;
                            if (state_err_count <= max_err_msgs)
                                `uvm_error("SB_STATE", $sformatf("Unexpected FSM transition to %s (golden has no more changes)",
                                           st_name(actual.fsm_state)))
                        end

                        // ----------------------------------------------------
                        // 2) Coarse CFO estimate, checked once per burst when
                        //    entering CostasAcq (compare per-case or fallback)
                        // ----------------------------------------------------
                        if (check_cfo && (actual.fsm_state == 3'd4) && !cfo_checked) begin
                            cfo_checked = 1'b1;
                            cfo_ext     = actual.coarse_cfo_est;
                            cfo_golden  = (exp_st != null && exp_st.has_exp_cfo) ? exp_st.exp_cfo : exp_coarse_cfo[23:0];
                            if (actual.coarse_cfo_est !== cfo_golden) begin
                                cfo_err_count++;
                                `uvm_error("SB_CFO", $sformatf("coarse_cfo_est=%0d expected=%0d",
                                           cfo_ext, $signed(cfo_golden)))
                            end else
                                `uvm_info("SB_CFO", $sformatf("coarse_cfo_est=%0d matches golden", cfo_ext), UVM_LOW)
                        end
                    end
                    prev_state = actual.fsm_state;
                end

                // ------------------------------------------------------------
                // 3) Output symbols vs golden (in order)
                // ------------------------------------------------------------
                if (actual.out_sym_valid === 1'b1) begin
                    strobe_count++;
                    last_lock = actual.lock_detect;
                    if (strobe_count <= 10)
                        `uvm_info("SB", $sformatf("RTL strobe %0d: out=(%0d,%0d) state=%s lock=%0b",
                                  strobe_count, actual.out_sym_i, actual.out_sym_q,
                                  st_name(actual.fsm_state), actual.lock_detect), UVM_LOW)

                    if (enable_check) begin
                        if (exp_fifo.try_get(expected)) begin
                            if ((actual.out_sym_i === expected.exp_i) &&
                                (actual.out_sym_q === expected.exp_q)) begin
                                correct_count++;
                            end else begin
                                wrong_count++;
                                diff_i = actual.out_sym_i - expected.exp_i;
                                diff_q = actual.out_sym_q - expected.exp_q;
                                if (wrong_count <= max_err_msgs)
                                    `uvm_error("SB_MISMATCH", $sformatf("Strobe %0d: RTL=(%0d,%0d) Exp=(%0d,%0d) diff=(%0d,%0d)",
                                               strobe_count, actual.out_sym_i, actual.out_sym_q,
                                               expected.exp_i, expected.exp_q, diff_i, diff_q))
                            end

                            if (actual.lock_detect !== expected.exp_lock) begin
                                lock_mismatch_count++;
                                if (check_lock)
                                    `uvm_error("SB_LOCK", $sformatf("Strobe %0d: lock_detect=%0b exp_lock=%0b",
                                               strobe_count, actual.lock_detect, expected.exp_lock))
                            end
                        end else begin
                            extra_count++;
                            if (extra_count <= max_err_msgs)
                                `uvm_error("SB_EXTRA", $sformatf("Strobe %0d: unexpected RTL output (golden queue empty)", strobe_count))
                        end
                    end
                end
            end
        endtask

        function void report_phase(uvm_phase phase);
            int leftover, st_leftover;
            super.report_phase(phase);
            leftover    = exp_fifo.used();
            st_leftover = st_fifo.used();

            `uvm_info("SB_SUMMARY", "----------------------------------------------------------", UVM_NONE)
            `uvm_info("SB_SUMMARY", "  SYNC SYSTEM TOP VERIFICATION SUMMARY", UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  RTL output symbols        : %0d", strobe_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Symbols matched           : %0d", correct_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Symbols mismatched        : %0d", wrong_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Extra (unexpected) symbols: %0d", extra_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Golden symbols not seen   : %0d", leftover), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  FSM state changes (RTL)   : %0d  errors: %0d  golden not seen: %0d",
                                              state_change_count, state_err_count, st_leftover), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Coarse CFO check errors   : %0d", cfo_err_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  lock_detect diffs (info)  : %0d  (last lock_detect = %0b)",
                                              lock_mismatch_count, last_lock), UVM_NONE)
            if (wrong_count > max_err_msgs)
                `uvm_info("SB_SUMMARY", $sformatf("  (only the first %0d mismatches were printed)", max_err_msgs), UVM_NONE)

            if (!enable_check) begin
                `uvm_info("SB_SUMMARY", "  STATUS: golden checking disabled for this run", UVM_NONE)
            end else if (wrong_count == 0 && extra_count == 0 && leftover == 0 && correct_count > 0 &&
                         state_err_count == 0 && st_leftover == 0 && cfo_err_count == 0) begin
                `uvm_info("SB_SUMMARY", "  STATUS: >>> PASSED (100% match to golden model) <<<", UVM_NONE)
            end else begin
                `uvm_error("SB_SUMMARY", "  STATUS: >>> FAILED <<<")
            end
            `uvm_info("SB_SUMMARY", "----------------------------------------------------------", UVM_NONE)
        endfunction
    endclass
endpackage
