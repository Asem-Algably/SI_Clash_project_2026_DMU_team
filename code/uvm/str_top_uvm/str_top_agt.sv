package str_top_agtt;
    import uvm_pkg::*;
    import str_top_drive::*;
    import str_top_sequencer::*;
    import str_top_monitor_pkg::*;
    import str_top_configuration::*;
    import str_top_sequence_item::*;
    `include "uvm_macros.svh"

    class str_top_agt extends uvm_agent;
        `uvm_component_utils(str_top_agt)

        str_top_driver    driver;
        str_top_sqr_class sqr;
        str_top_monitor   monitor;
        str_top_confg     cfg;

        uvm_analysis_port #(str_top_seq_item) agt_ap;   // actual outputs (monitor)
        uvm_analysis_port #(str_top_seq_item) exp_ap;   // expected symbols (driver)

        function new(string name = "str_top_agt", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(str_top_confg)::get(this, "", "CFG", cfg))
                `uvm_fatal("AGT_BUILD", "No CFG found in config_db")

            monitor = str_top_monitor::type_id::create("mon", this);
            if (cfg.is_active == UVM_ACTIVE) begin
                driver = str_top_driver::type_id::create("driver", this);
                sqr    = str_top_sqr_class::type_id::create("sqr", this);
            end
            agt_ap = new("agt_ap", this);
            exp_ap = new("exp_ap", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            monitor.str_top_test_vif = cfg.str_top_test_vif;
            monitor.mon_ap.connect(agt_ap);
            if (cfg.is_active == UVM_ACTIVE) begin
                driver.str_top_test_vif = cfg.str_top_test_vif;
                driver.seq_item_port.connect(sqr.seq_item_export);
                driver.drv_ap.connect(exp_ap);
            end
        endfunction
    endclass
endpackage
