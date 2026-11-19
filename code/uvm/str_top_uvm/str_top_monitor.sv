package str_top_monitor;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import str_top_sequence_item::*;
    class str_top_monitor extends uvm_monitor;
        `uvm_component_utils(str_top_monitor)
        str_top_seq_item item;
        virtual str_top_inter str_top_test_vif;
        uvm_analysis_port #(str_top_seq_item) mon_ap;
        function new(string name = "str_top_monitor",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_ap=new("mon_ap",this);
        endfunction
        task  run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            item = str_top_seq_item::type_id::create("item");
            @(negedge str_top_test_vif.clk);
            //assign item variables
            mon_ap.write(item);
        end
    endtask //
    endclass //className extends superClass
endpackage
