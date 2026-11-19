package str_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class str_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(str_top_seq_item)
        function new(string name = "str_top_seq_item");
            super.new(name);
        endfunction
        // define variables and constraints

    endclass //seq_item extends superClass
endpackage
