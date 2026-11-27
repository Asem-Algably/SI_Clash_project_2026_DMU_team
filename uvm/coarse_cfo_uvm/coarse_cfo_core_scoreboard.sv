package coarse_cfo_core_scoreborad_pck;
    import uvm_pkg::*;
    import coarse_cfo_core_sequence_item::*;
    `include "uvm_macros.svh"

    class coarse_cfo_core_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(coarse_cfo_core_scoreborad)

        uvm_analysis_export #(coarse_cfo_core_seq_item) sb_export;
        uvm_analysis_export #(coarse_cfo_core_seq_item) exp_export;
        uvm_tlm_analysis_fifo #(coarse_cfo_core_seq_item) sb_fifo;
        uvm_tlm_analysis_fifo #(coarse_cfo_core_seq_item) exp_fifo;

        int correct_count = 0;
        int wrong_count   = 0;
        int extra_count   = 0;
        int strobe_count  = 0;
        bit check_enable  = 1'b1;

        function new(string name = "coarse_cfo_core_scoreborad", uvm_component parent = null);
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
            coarse_cfo_core_seq_item item, expected;
            forever begin
                sb_fifo.get(item);
                if (item.o_valid === 1'b1) begin
                    strobe_count++;
                    if (check_enable) begin
                        if (exp_fifo.try_get(expected)) begin
                            if (item.cfo === expected.exp_cfo) begin
                                correct_count++;
                                `uvm_info("SB", $sformatf("MATCH %0d: cfo=%0d (0x%06h)", strobe_count, item.cfo, item.cfo[23:0]), UVM_LOW)
                            end else begin
                                wrong_count++;
                                `uvm_error("SB", $sformatf("MISMATCH %0d: got=%0d (0x%06h), exp=%0d (0x%06h)",
                                           strobe_count, item.cfo, item.cfo[23:0], expected.exp_cfo, expected.exp_cfo[23:0]))
                            end
                        end else begin
                            extra_count++;
                            `uvm_error("SB_EXTRA", $sformatf("Unexpected valid CFO pulse %0d while exp_fifo is empty", strobe_count))
                        end
                    end
                end
            end
        endtask

        function void report_phase(uvm_phase phase);
            int leftover = exp_fifo.used();
            super.report_phase(phase);
            `uvm_info("SB_SUMMARY", $sformatf("COARSE CFO: outputs=%0d, match=%0d, wrong=%0d, extra=%0d, unseen=%0d",
                      strobe_count, correct_count, wrong_count, extra_count, leftover), UVM_NONE)
            if (!check_enable)
                `uvm_info("SB_SUMMARY", "STATUS: golden checking disabled", UVM_NONE)
            else if (wrong_count == 0 && extra_count == 0 && leftover == 0 && correct_count > 0)
                `uvm_info("SB_SUMMARY", "STATUS: >>> PASSED <<<", UVM_NONE)
            else
                `uvm_error("SB_SUMMARY", "STATUS: >>> FAILED <<<")
        endfunction
    endclass
endpackage