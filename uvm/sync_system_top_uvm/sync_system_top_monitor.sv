package sync_system_top_monitor_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import sync_system_top_sequence_item::*;

    class sync_system_top_monitor extends uvm_monitor;
        `uvm_component_utils(sync_system_top_monitor)

        virtual sync_system_top_inter sync_system_top_test_vif;
        uvm_analysis_port #(sync_system_top_seq_item) mon_ap;

        function new(string name = "sync_system_top_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap", this);
        endfunction

        task run_phase(uvm_phase phase);
            sync_system_top_seq_item item;
            forever begin
                @(negedge sync_system_top_test_vif.clk);
                item = sync_system_top_seq_item::type_id::create("item");

                // inputs (needed for coverage)
                item.rst_n         = sync_system_top_test_vif.rst_n;
                item.valid         = sync_system_top_test_vif.in_sample_valid;
                item.mod_type      = sync_system_top_test_vif.mod_type;
                item.dft_sel       = sync_system_top_test_vif.dft_sel;
                item.force_w_en    = sync_system_top_test_vif.force_w_en;
                item.force_cfo_en  = sync_system_top_test_vif.force_cfo_en;
                item.force_freq_en = sync_system_top_test_vif.force_freq_en;

                // outputs
                item.out_sym_valid      = sync_system_top_test_vif.out_sym_valid;
                item.out_sym_i          = sync_system_top_test_vif.out_sym_i;
                item.out_sym_q          = sync_system_top_test_vif.out_sym_q;
                item.coarse_cfo_est     = sync_system_top_test_vif.coarse_cfo_est;
                item.fine_cfo_est       = sync_system_top_test_vif.fine_cfo_est;
                item.lock_detect        = sync_system_top_test_vif.lock_detect;
                item.flush_active       = sync_system_top_test_vif.flush_active;
                item.valid_during_flush = sync_system_top_test_vif.valid_during_flush;
                item.dft_obs_data       = sync_system_top_test_vif.dft_obs_data;

                // internal taps
                item.fsm_state    = sync_system_top_test_vif.fsm_state;
                item.str_lock     = sync_system_top_test_vif.str_lock;
                item.costas_lock  = sync_system_top_test_vif.costas_lock;
                item.coarse_valid = sync_system_top_test_vif.coarse_valid;
                item.str_valid    = sync_system_top_test_vif.str_valid;

                mon_ap.write(item);
            end
        endtask
    endclass
endpackage
