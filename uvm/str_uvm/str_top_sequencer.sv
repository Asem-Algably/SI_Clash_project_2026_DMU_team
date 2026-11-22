package str_top_sequencer;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import str_top_sequence_item::*;

    class str_top_sqr_class extends uvm_sequencer #(str_top_seq_item);
        `uvm_component_utils(str_top_sqr_class)

        function new(string name = "str_top_sqr_class", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass
endpackage
