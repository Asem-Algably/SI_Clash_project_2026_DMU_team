package sync_system_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class sync_system_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(sync_system_top_seq_item)
        function new(string name = "sync_system_top_seq_item");
            super.new(name);
        endfunction
        // define variables and constraints

    endclass //seq_item extends superClass
endpackage
