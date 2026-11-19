package costas_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class costas_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(costas_top_seq_item)
        function new(string name = "costas_top_seq_item");
            super.new(name);
        endfunction
        // define variables and constraints

    endclass //seq_item extends superClass
endpackage
