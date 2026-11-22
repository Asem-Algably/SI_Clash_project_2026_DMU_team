package reset_sequence;
    import derotator_sequence_item::*;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class reset_seq extends uvm_sequence#(derotator_seq_item);
        `uvm_object_utils(reset_seq)
        derotator_seq_item item;
        
        function new(string name = "reset_seq");
            super.new(name);
        endfunction
        
        task body();
            item = derotator_seq_item::type_id::create("item");
            start_item(item);
            // Randomize the item to drive random inputs
            if(!item.randomize()) `uvm_error("SEQ", "Randomization failed")
            finish_item(item);
        endtask
    endclass
endpackage