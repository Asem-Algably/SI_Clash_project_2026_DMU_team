package coarse_cfo_core_agtt;
    import uvm_pkg::*;
    import coarse_cfo_core_drive::*;
    import coarse_cfo_core_sequencer::*;
    import coarse_cfo_core_monitor::*;
    import coarse_cfo_core_configuration::*;
    import coarse_cfo_core_sequence_item::*;
    `include "uvm_macros.svh"
    class coarse_cfo_core_agt extends uvm_agent;
        `uvm_component_utils(coarse_cfo_core_agt)
        coarse_cfo_core_driver driver;
        coarse_cfo_core_sqr_class sqr;
        coarse_cfo_core_monitor monitor;
        coarse_cfo_core_confg cfg;
        uvm_analysis_port #(coarse_cfo_core_seq_item) agt_ap;
        function new(string name="coarse_cfo_core_agt", uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            monitor = coarse_cfo_core_monitor::type_id::create("mon",this);
        if(!uvm_config_db #(coarse_cfo_core_confg) :: get(this,"","CFG",cfg))
        `uvm_fatal("build_phase","no");
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver = coarse_cfo_core_driver::type_id::create("driver",this);
            sqr = coarse_cfo_core_sqr_class::type_id::create("sqr",this);
        end
        agt_ap = new("agt_ap",this);
        endfunction
        function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        monitor.coarse_cfo_core_test_vif=cfg.coarse_cfo_core_test_vif;
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver.coarse_cfo_core_test_vif=cfg.coarse_cfo_core_test_vif;
            driver.seq_item_port.connect(sqr.seq_item_export);
        end
        monitor.mon_ap.connect(agt_ap);
    endfunction
    endclass //className extends superClass
endpackage
