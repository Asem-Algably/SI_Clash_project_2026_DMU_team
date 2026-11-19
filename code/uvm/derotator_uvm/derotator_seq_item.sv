package derotator_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class derotator_seq_item extends uvm_sequence_item;
        `uvm_object_utils(derotator_seq_item)
        function new(string name = "derotator_seq_item");
            super.new(name);
        endfunction
        // define variables and constraints

    endclass //seq_item extends superClass
endpackage
