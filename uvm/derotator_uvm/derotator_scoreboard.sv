package derotator_scoreborad_pck;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"

    // الماكرو لازم يكون هنا جوه الـ package
    `uvm_analysis_imp_decl(_drv)
    `uvm_analysis_imp_decl(_mon)

    class derotator_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(derotator_scoreborad)

        uvm_analysis_imp_drv #(derotator_seq_item, derotator_scoreborad) drv_imp;
        uvm_analysis_imp_mon #(derotator_seq_item, derotator_scoreborad) mon_imp;
        
        derotator_seq_item expected_queue[$];
        int correct_count = 0;
        int wrong_count   = 0;
        int extra_count   = 0;
        int strobe_count  = 0;

        function new(string name = "derotator_scoreborad", uvm_component parent = null);
            super.new(name,parent);
        endfunction

        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            drv_imp = new("drv_imp", this);
            mon_imp = new("mon_imp", this);
        endfunction

        virtual function void write_drv(derotator_seq_item item);
            expected_queue.push_back(item);
        endfunction

        virtual function void write_mon(derotator_seq_item item);
            derotator_seq_item exp_item;
            if (item.m_axis_valid_o === 1'b1) begin
                strobe_count++;
                if (expected_queue.size() > 0) begin
                    exp_item = expected_queue.pop_front();
                    if (item.m_axis_i_sym_o === exp_item.exp_i && item.m_axis_q_sym_o === exp_item.exp_q) begin
                        correct_count++;
                    end else begin
                        wrong_count++;
                        `uvm_error("SCB", $sformatf("Strobe %0d mismatch! Exp=(%0d,%0d) [0x%04h,0x%04h] | Act=(%0d,%0d) [0x%04h,0x%04h]",
                                   strobe_count, exp_item.exp_i, exp_item.exp_q, exp_item.exp_i, exp_item.exp_q,
                                   item.m_axis_i_sym_o, item.m_axis_q_sym_o, item.m_axis_i_sym_o, item.m_axis_q_sym_o))
                    end
                end else begin
                    extra_count++;
                    `uvm_error("SCB_EXTRA", $sformatf("Strobe %0d: unexpected valid output while expected_queue is empty", strobe_count))
                end
            end
        endfunction

        function void report_phase(uvm_phase phase);
            int leftover = expected_queue.size();
            super.report_phase(phase);
            `uvm_info("SB_SUMMARY", $sformatf("DEROTATOR: strobes=%0d, match=%0d, wrong=%0d, extra=%0d, unseen=%0d",
                      strobe_count, correct_count, wrong_count, extra_count, leftover), UVM_NONE)
            if (wrong_count == 0 && extra_count == 0 && leftover == 0 && correct_count > 0)
                `uvm_info("SB_SUMMARY", "STATUS: >>> PASSED <<<", UVM_NONE)
            else
                `uvm_error("SB_SUMMARY", "STATUS: >>> FAILED <<<")
        endfunction
    endclass
endpackage