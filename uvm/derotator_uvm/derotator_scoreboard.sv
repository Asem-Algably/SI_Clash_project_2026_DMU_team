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
        static int correct_count = 0;
        static int wrong_count = 0;

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
            if (expected_queue.size() > 0) begin
                exp_item = expected_queue.pop_front();
                if (item.m_axis_i_sym_o == exp_item.exp_i && item.m_axis_q_sym_o == exp_item.exp_q) begin
                    correct_count++;
                end else begin
                    wrong_count++;
                    `uvm_error("SCB", $sformatf("Mismatch! Exp I: %h, Exp Q: %h | Act I: %h, Act Q: %h", 
                               exp_item.exp_i, exp_item.exp_q, item.m_axis_i_sym_o, item.m_axis_q_sym_o))
                end
            end
        endfunction
    endclass
endpackage