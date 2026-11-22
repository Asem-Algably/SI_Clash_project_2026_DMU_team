package str_top_scoreborad_pck;
    import uvm_pkg::*;
    import str_top_sequence_item::*;
    `include "uvm_macros.svh"

    class str_top_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(str_top_scoreborad)

        uvm_analysis_export #(str_top_seq_item)   sb_export;    // actual (monitor)
        uvm_analysis_export #(str_top_seq_item)   exp_export;   // expected (driver)
        uvm_tlm_analysis_fifo #(str_top_seq_item) sb_fifo;
        uvm_tlm_analysis_fifo #(str_top_seq_item) exp_fifo;

        bit enable_check  = 1'b1;   // test clears it for non-golden sequences
        bit check_lock    = 1'b0;   // lock_o is informational (as in the plain TB)
        int max_err_msgs  = 20;     // limit on printed mismatch messages

        int correct_count       = 0;
        int wrong_count         = 0;
        int extra_count         = 0;
        int strobe_count        = 0;
        int lock_mismatch_count = 0;

        function new(string name = "str_top_scoreborad", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sb_export  = new("sb_export",  this);
            exp_export = new("exp_export", this);
            sb_fifo    = new("sb_fifo",    this);
            exp_fifo   = new("exp_fifo",   this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
            exp_export.connect(exp_fifo.analysis_export);
        endfunction

        task run_phase(uvm_phase phase);
            str_top_seq_item actual;
            str_top_seq_item expected;
            int diff_i, diff_q;

            forever begin
                sb_fifo.get(actual);

                if (actual.m_axis_valid_o === 1'b1) begin
                    strobe_count++;
                    if (strobe_count <= 10)
                        `uvm_info("SB", $sformatf("RTL strobe %0d: out=(%0d,%0d)",
                                  strobe_count, actual.m_axis_i_sym_o, actual.m_axis_q_sym_o), UVM_LOW)

                    if (enable_check) begin
                        if (exp_fifo.try_get(expected)) begin
                            if ((actual.m_axis_i_sym_o === expected.exp_i) &&
                                (actual.m_axis_q_sym_o === expected.exp_q)) begin
                                correct_count++;
                            end else begin
                                wrong_count++;
                                diff_i = actual.m_axis_i_sym_o - expected.exp_i;
                                diff_q = actual.m_axis_q_sym_o - expected.exp_q;
                                if (wrong_count <= max_err_msgs)
                                    `uvm_error("SB_MISMATCH", $sformatf("Strobe %0d: RTL=(%0d,%0d) Exp=(%0d,%0d) diff=(%0d,%0d)",
                                               strobe_count, actual.m_axis_i_sym_o, actual.m_axis_q_sym_o,
                                               expected.exp_i, expected.exp_q, diff_i, diff_q))
                            end

                            if (actual.lock_o !== expected.exp_lock) begin
                                lock_mismatch_count++;
                                if (check_lock)
                                    `uvm_error("SB_LOCK", $sformatf("Strobe %0d: lock_o=%0b exp_lock=%0b",
                                               strobe_count, actual.lock_o, expected.exp_lock))
                            end
                        end else begin
                            extra_count++;
                            if (extra_count <= max_err_msgs)
                                `uvm_error("SB_EXTRA", $sformatf("Strobe %0d: unexpected RTL strobe (golden queue empty)", strobe_count))
                        end
                    end
                end
            end
        endtask

        function void report_phase(uvm_phase phase);
            int leftover;
            super.report_phase(phase);
            leftover = exp_fifo.used();

            `uvm_info("SB_SUMMARY", "----------------------------------------------------------", UVM_NONE)
            `uvm_info("SB_SUMMARY", "  STR VERIFICATION SUMMARY", UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  RTL strobes produced     : %0d", strobe_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Symbols matched          : %0d", correct_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Symbols mismatched       : %0d", wrong_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Extra (unexpected) strobes: %0d", extra_count), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  Golden symbols not seen  : %0d", leftover), UVM_NONE)
            `uvm_info("SB_SUMMARY", $sformatf("  lock_o differences (info): %0d", lock_mismatch_count), UVM_NONE)
            if (wrong_count > max_err_msgs)
                `uvm_info("SB_SUMMARY", $sformatf("  (only the first %0d mismatches were printed)", max_err_msgs), UVM_NONE)

            if (!enable_check) begin
                `uvm_info("SB_SUMMARY", "  STATUS: golden checking disabled for this run", UVM_NONE)
            end else if (wrong_count == 0 && extra_count == 0 && leftover == 0 && correct_count > 0) begin
                `uvm_info("SB_SUMMARY", "  STATUS: >>> PASSED (100% symbol match to golden model) <<<", UVM_NONE)
            end else begin
                `uvm_error("SB_SUMMARY", "  STATUS: >>> FAILED <<<")
            end
            `uvm_info("SB_SUMMARY", "----------------------------------------------------------", UVM_NONE)
        endfunction
    endclass
endpackage
