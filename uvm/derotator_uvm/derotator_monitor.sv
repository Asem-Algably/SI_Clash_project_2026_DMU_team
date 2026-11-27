package derotator_monitor;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"
    
    class derotator_monitor extends uvm_monitor;
        `uvm_component_utils(derotator_monitor)
        virtual derotator_inter derotator_test_vif;
        uvm_analysis_port #(derotator_seq_item) mon_ap;
        
        function new(string name = "derotator_monitor",uvm_component parent = null);
            super.new(name,parent);
        endfunction
        
        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap",this);
        endfunction
        
        task run_phase(uvm_phase phase);
            derotator_seq_item item;
            super.run_phase(phase);

            forever begin
                @(posedge derotator_test_vif.clk);
                #1;
                item = derotator_seq_item::type_id::create("item");
                item.rst_ni          = derotator_test_vif.rst_ni;
                item.s_axis_valid_i  = derotator_test_vif.s_axis_valid_i;
                item.s_axis_i_sym_i  = derotator_test_vif.s_axis_i_sym_i;
                item.s_axis_q_sym_i  = derotator_test_vif.s_axis_q_sym_i;
                item.force_freq_en_i = derotator_test_vif.force_freq_en_i;
                item.m_axis_valid_o  = derotator_test_vif.m_axis_valid_o;
                item.m_axis_i_sym_o  = derotator_test_vif.m_axis_i_sym_o;
                item.m_axis_q_sym_o  = derotator_test_vif.m_axis_q_sym_o;
                item.phase_o         = derotator_test_vif.phase_o;
                item.freq_word_o     = derotator_test_vif.freq_word_o;

                mon_ap.write(item);
            end
        endtask
    endclass
endpackage