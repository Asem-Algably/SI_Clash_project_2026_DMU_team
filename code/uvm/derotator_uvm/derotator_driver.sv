package derotator_drive;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    import derotator_configuration::*;
    `include "uvm_macros.svh"
    
    class derotator_driver extends uvm_driver #(derotator_seq_item);
        `uvm_component_utils(derotator_driver)
        virtual derotator_inter derotator_test_vif;
        
        // Send expected data to Scoreboard
        uvm_analysis_port #(derotator_seq_item) drv_ap;

        function new(string name="derotator_driver",uvm_component parent = null);
            super.new(name,parent);
        endfunction
        
        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            drv_ap = new("drv_ap", this);
        endfunction
        
        task run_phase (uvm_phase phase);
            super.run_phase(phase);
            
            derotator_test_vif.rst_ni <= 0;
            derotator_test_vif.s_axis_valid_i <= 0;
            @(negedge derotator_test_vif.clk);
            derotator_test_vif.rst_ni <= 1;
            
            forever begin
                seq_item_port.get_next_item(req);
                
                // Drive inputs
                @(negedge derotator_test_vif.clk);
                derotator_test_vif.s_axis_valid_i   <= req.s_axis_valid_i;
                derotator_test_vif.s_axis_i_sym_i   <= req.s_axis_i_sym_i;
                derotator_test_vif.s_axis_q_sym_i   <= req.s_axis_q_sym_i;
                derotator_test_vif.coarse_valid_i   <= req.coarse_valid_i;
                derotator_test_vif.coarse_word_i    <= req.coarse_word_i;
                derotator_test_vif.freq_adj_valid_i <= req.freq_adj_valid_i;
                derotator_test_vif.freq_adj_i       <= req.freq_adj_i;
                derotator_test_vif.force_freq_en_i  <= req.force_freq_en_i;
                derotator_test_vif.force_freq_i     <= req.force_freq_i;
                derotator_test_vif.phase_adj_valid_i<= req.phase_adj_valid_i;
                derotator_test_vif.phase_adj_i      <= req.phase_adj_i;
                
                // Send to scoreboard so it knows what to expect
                drv_ap.write(req);
                
                seq_item_port.item_done();
            end
        endtask
    endclass
endpackage