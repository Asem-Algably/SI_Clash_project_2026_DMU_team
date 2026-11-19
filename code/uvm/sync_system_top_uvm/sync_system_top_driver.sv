package sync_system_top_drive;
    import uvm_pkg::*;
    import sync_system_top_configuration::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"
    class sync_system_top_driver extends uvm_driver#(sync_system_top_seq_item);
    `uvm_component_utils(sync_system_top_driver)
    sync_system_top_seq_item item;
    virtual sync_system_top_inter sync_system_top_test_vif;
        function new(string name="sync_system_top_driver",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    endfunction
        task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever begin
                item = sync_system_top_seq_item::type_id::create("item");
                seq_item_port.get_next_item(item);
                // drive the interface
                @(negedge sync_system_top_test_vif.clk);
                seq_item_port.item_done();
            end
        endtask //run_phase
    endclass //className extends superClass
endpackage
