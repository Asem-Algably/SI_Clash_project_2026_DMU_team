package sync_system_top_monitor;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import sync_system_top_sequence_item::*;
    class sync_system_top_monitor extends uvm_monitor;
        `uvm_component_utils(sync_system_top_monitor)
        sync_system_top_seq_item item;
        virtual sync_system_top_inter sync_system_top_test_vif;
        uvm_analysis_port #(sync_system_top_seq_item) mon_ap;
        function new(string name = "sync_system_top_monitor",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_ap=new("mon_ap",this);
        endfunction
        task  run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            item = sync_system_top_seq_item::type_id::create("item");
            @(negedge sync_system_top_test_vif.clk);
            //assign item variables
            mon_ap.write(item);
        end
    endtask //
    endclass //className extends superClass
endpackage
