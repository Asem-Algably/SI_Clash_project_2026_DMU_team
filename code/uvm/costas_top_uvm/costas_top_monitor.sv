package costas_top_monitor;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import costas_top_sequence_item::*;
    class costas_top_monitor extends uvm_monitor;
        `uvm_component_utils(costas_top_monitor)
        costas_top_seq_item item;
        virtual costas_top_inter costas_top_test_vif;
        uvm_analysis_port #(costas_top_seq_item) mon_ap;
        function new(string name = "costas_top_monitor",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            mon_ap=new("mon_ap",this);
        endfunction
        task  run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            item = costas_top_seq_item::type_id::create("item");
            @(negedge costas_top_test_vif.clk);
            //assign item variables
            mon_ap.write(item);
        end
    endtask //
    endclass //className extends superClass
endpackage
