package costas_top_scoreborad_pck;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class costas_top_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(costas_top_scoreborad)

        uvm_analysis_export #(costas_top_seq_item) sb_export;
        uvm_analysis_export #(costas_top_seq_item) exp_export;
        uvm_tlm_analysis_fifo #(costas_top_seq_item) sb_fifo;
        uvm_tlm_analysis_fifo #(costas_top_seq_item) exp_fifo;
        costas_top_seq_item item;

        costas_top_seq_item exp_f_q[$];
        costas_top_seq_item exp_p_q[$];

        bit enable_check   = 1'b1;
        int correct_count  = 0;
        int wrong_count    = 0;
        int extra_count    = 0;
        int max_err_msgs   = 20;

        function new(string name = "costas_top_scoreborad", uvm_component parent = null);
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
            costas_top_seq_item tmp, exp_item;
            forever begin
                sb_fifo.get(item);
                while (exp_fifo.try_get(tmp)) begin
                    if (tmp.exp_fval === 1'b1) exp_f_q.push_back(tmp);
                    if (tmp.exp_pval === 1'b1) exp_p_q.push_back(tmp);
                end

                if (!enable_check) continue;

                if (item.freq_adj_valid === 1'b1) begin
                    if (exp_f_q.size() > 0) begin
                        exp_item = exp_f_q.pop_front();
                        if (item.freq_adj === exp_item.exp_freq_adj) begin
                            correct_count++;
                        end else begin
                            wrong_count++;
                            if (wrong_count <= max_err_msgs)
                                `uvm_error("SB", $sformatf("FREQ MISMATCH: got=%0d (0x%08h), exp=%0d (0x%08h)",
                                           item.freq_adj, item.freq_adj, exp_item.exp_freq_adj, exp_item.exp_freq_adj))
                        end
                    end else begin
                        extra_count++;
                        if (extra_count <= max_err_msgs)
                            `uvm_error("SB_EXTRA", "Unexpected freq_adj_valid pulse while exp_f_q is empty")
                    end
                end

                if (item.phase_adj_valid === 1'b1) begin
                    if (exp_p_q.size() > 0) begin
                        exp_item = exp_p_q.pop_front();
                        if (item.phase_adj === exp_item.exp_phase_adj) begin
                            correct_count++;
                        end else begin
                            wrong_count++;
                            if (wrong_count <= max_err_msgs)
                                `uvm_error("SB", $sformatf("PHASE MISMATCH: got=0x%08h, exp=0x%08h",
                                           item.phase_adj, exp_item.exp_phase_adj))
                        end
                    end else begin
                        extra_count++;
                        if (extra_count <= max_err_msgs)
                            `uvm_error("SB_EXTRA", "Unexpected phase_adj_valid pulse while exp_p_q is empty")
                    end
                end
            end
        endtask

        function void report_phase(uvm_phase phase);
            costas_top_seq_item tmp;
            int left_f, left_p;
            while (exp_fifo.try_get(tmp)) begin
                if (tmp.exp_fval === 1'b1) exp_f_q.push_back(tmp);
                if (tmp.exp_pval === 1'b1) exp_p_q.push_back(tmp);
            end
            left_f = exp_f_q.size();
            left_p = exp_p_q.size();
            super.report_phase(phase);
            `uvm_info("SB_SUMMARY", $sformatf("COSTAS: match=%0d, wrong=%0d, extra=%0d, unseen_freq=%0d, unseen_phase=%0d",
                      correct_count, wrong_count, extra_count, left_f, left_p), UVM_NONE)
            if (!enable_check)
                `uvm_info("SB_SUMMARY", "STATUS: golden checking disabled", UVM_NONE)
            else if (wrong_count == 0 && extra_count == 0 && left_f == 0 && left_p == 0 && correct_count > 0)
                `uvm_info("SB_SUMMARY", "STATUS: >>> PASSED <<<", UVM_NONE)
            else
                `uvm_error("SB_SUMMARY", "STATUS: >>> FAILED <<<")
        endfunction
    endclass
endpackage