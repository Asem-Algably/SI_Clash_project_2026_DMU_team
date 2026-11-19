package derotator_drive;
    import uvm_pkg::*;
    import derotator_configuration::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"
    class derotator_driver extends uvm_driver#(derotator_seq_item);
    `uvm_component_utils(derotator_driver)
    derotator_seq_item item;
    virtual derotator_inter derotator_test_vif;
        function new(string name="derotator_driver",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    endfunction
        task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever begin
                item = derotator_seq_item::type_id::create("item");
                seq_item_port.get_next_item(item);
                // drive the interface
                @(negedge derotator_test_vif.clk);
                seq_item_port.item_done();
            end
        endtask //run_phase
    endclass //className extends superClass
endpackage
