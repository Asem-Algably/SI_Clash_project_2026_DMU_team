package derotator_monitor;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import derotator_sequence_item::*;
    class derotator_monitor extends uvm_monitor;
        `uvm_component_utils(derotator_monitor)
        derotator_seq_item item;
        virtual derotator_inter derotator_test_vif;
        uvm_analysis_port #(derotator_seq_item) mon_ap;
        function new(string name = "derotator_monitor",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_ap=new("mon_ap",this);
        endfunction
        task  run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            item = derotator_seq_item::type_id::create("item");
            @(negedge derotator_test_vif.clk);
            //assign item variables
            mon_ap.write(item);
        end
    endtask //
    endclass //className extends superClass
endpackage
