package costas_top_agtt;
    import uvm_pkg::*;
    import costas_top_drive::*;
    import costas_top_sequencer::*;
    import costas_top_monitor::*;
    import costas_top_configuration::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"
    class costas_top_agt extends uvm_agent;
        `uvm_component_utils(costas_top_agt)
        costas_top_driver driver;
        costas_top_sqr_class sqr;
        costas_top_monitor monitor;
        costas_top_confg cfg;
        uvm_analysis_port #(costas_top_seq_item) agt_ap;
        uvm_analysis_port #(costas_top_seq_item) exp_ap;
        function new(string name="costas_top_agt", uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            monitor = costas_top_monitor::type_id::create("mon",this);
        if(!uvm_config_db #(costas_top_confg) :: get(this,"","CFG",cfg))
        `uvm_fatal("build_phase","no");
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver = costas_top_driver::type_id::create("driver",this);
            sqr = costas_top_sqr_class::type_id::create("sqr",this);
        end
        agt_ap = new("agt_ap",this);
        exp_ap = new("exp_ap",this);
        endfunction
        function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        monitor.costas_top_test_vif=cfg.costas_top_test_vif;
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver.costas_top_test_vif=cfg.costas_top_test_vif;
            driver.seq_item_port.connect(sqr.seq_item_export);
            driver.drv_ap.connect(exp_ap);
        end
        monitor.mon_ap.connect(agt_ap);
    endfunction
    endclass //className extends superClass
endpackage
