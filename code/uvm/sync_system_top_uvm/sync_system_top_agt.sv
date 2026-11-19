package sync_system_top_agtt;
    import uvm_pkg::*;
    import sync_system_top_drive::*;
    import sync_system_top_sequencer::*;
    import sync_system_top_monitor::*;
    import sync_system_top_configuration::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"
    class sync_system_top_agt extends uvm_agent;
        `uvm_component_utils(sync_system_top_agt)
        sync_system_top_driver driver;
        sync_system_top_sqr_class sqr;
        sync_system_top_monitor monitor;
        sync_system_top_confg cfg;
        uvm_analysis_port #(sync_system_top_seq_item) agt_ap;
        function new(string name="sync_system_top_agt", uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            monitor = sync_system_top_monitor::type_id::create("mon",this);
        if(!uvm_config_db #(sync_system_top_confg) :: get(this,"","CFG",cfg))
        `uvm_fatal("build_phase","no");
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver = sync_system_top_driver::type_id::create("driver",this);
            sqr = sync_system_top_sqr_class::type_id::create("sqr",this);
        end
        agt_ap = new("agt_ap",this);
        endfunction
        function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        monitor.sync_system_top_test_vif=cfg.sync_system_top_test_vif;
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver.sync_system_top_test_vif=cfg.sync_system_top_test_vif;
            driver.seq_item_port.connect(sqr.seq_item_export);
        end
        monitor.mon_ap.connect(agt_ap);
    endfunction
    endclass //className extends superClass
endpackage
