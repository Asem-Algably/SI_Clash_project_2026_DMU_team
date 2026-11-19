package str_top_drive;
    import uvm_pkg::*;
    import str_top_configuration::*;
    import str_top_sequence_item::*;
    `include "uvm_macros.svh"
    class str_top_driver extends uvm_driver#(str_top_seq_item);
    `uvm_component_utils(str_top_driver)
    str_top_seq_item item;
    virtual str_top_inter str_top_test_vif;
        function new(string name="str_top_driver",uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    endfunction
        task run_phase (uvm_phase phase);
            super.run_phase(phase);
            forever begin
                item = str_top_seq_item::type_id::create("item");
                seq_item_port.get_next_item(item);
                // drive the interface
                @(negedge str_top_test_vif.clk);
                seq_item_port.item_done();
            end
        endtask //run_phase
    endclass //className extends superClass
endpackage
