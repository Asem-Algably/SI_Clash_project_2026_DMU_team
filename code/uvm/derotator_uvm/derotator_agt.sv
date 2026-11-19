package derotator_agtt;
    import uvm_pkg::*;
    import derotator_drive::*;
    import derotator_sequencer::*;
    import derotator_monitor::*;
    import derotator_configuration::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"
    class derotator_agt extends uvm_agent;
        `uvm_component_utils(derotator_agt)
        derotator_driver driver;
        derotator_sqr_class sqr;
        derotator_monitor monitor;
        derotator_confg cfg;
        uvm_analysis_port #(derotator_seq_item) agt_ap;
        function new(string name="derotator_agt", uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            monitor = derotator_monitor::type_id::create("mon",this);
        if(!uvm_config_db #(derotator_confg) :: get(this,"","CFG",cfg))
        `uvm_fatal("build_phase","no");
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver = derotator_driver::type_id::create("driver",this);
            sqr = derotator_sqr_class::type_id::create("sqr",this);
        end
        agt_ap = new("agt_ap",this);
        endfunction
        function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        monitor.derotator_test_vif=cfg.derotator_test_vif;
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver.derotator_test_vif=cfg.derotator_test_vif;
            driver.seq_item_port.connect(sqr.seq_item_export);
        end
        monitor.mon_ap.connect(agt_ap);
    endfunction
    endclass //className extends superClass
endpackage
