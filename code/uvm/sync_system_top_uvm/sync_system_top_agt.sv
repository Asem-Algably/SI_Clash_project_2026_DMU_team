package sync_system_top_agtt;
    import uvm_pkg::*;
    import sync_system_top_drive::*;
    import sync_system_top_sequencer::*;
    import sync_system_top_monitor_pkg::*;
    import sync_system_top_configuration::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"

    class sync_system_top_agt extends uvm_agent;
        `uvm_component_utils(sync_system_top_agt)

        sync_system_top_driver    driver;
        sync_system_top_sqr_class sqr;
        sync_system_top_monitor   monitor;
        sync_system_top_confg     cfg;

        uvm_analysis_port #(sync_system_top_seq_item) agt_ap;   // actual outputs (monitor)
        uvm_analysis_port #(sync_system_top_seq_item) exp_ap;   // expected output symbols (driver)
        uvm_analysis_port #(sync_system_top_seq_item) st_ap;    // expected FSM state changes (driver)

        function new(string name = "sync_system_top_agt", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(sync_system_top_confg)::get(this, "", "CFG", cfg))
                `uvm_fatal("AGT_BUILD", "No CFG found in config_db")

            monitor = sync_system_top_monitor::type_id::create("mon", this);
            if (cfg.is_active == UVM_ACTIVE) begin
                driver = sync_system_top_driver::type_id::create("driver", this);
                sqr    = sync_system_top_sqr_class::type_id::create("sqr", this);
            end
            agt_ap = new("agt_ap", this);
            exp_ap = new("exp_ap", this);
            st_ap  = new("st_ap",  this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            monitor.sync_system_top_test_vif = cfg.sync_system_top_test_vif;
            monitor.mon_ap.connect(agt_ap);
            if (cfg.is_active == UVM_ACTIVE) begin
                driver.sync_system_top_test_vif = cfg.sync_system_top_test_vif;
                driver.seq_item_port.connect(sqr.seq_item_export);
                driver.drv_ap.connect(exp_ap);
                driver.st_ap.connect(st_ap);
            end
        endfunction
    endclass
endpackage
