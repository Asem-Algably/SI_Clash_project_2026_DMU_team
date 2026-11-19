package costas_top_sequencer;
import uvm_pkg::*;
`include "uvm_macros.svh"
import costas_top_sequence_item::*;
class costas_top_sqr_class extends uvm_sequencer #(costas_top_seq_item);
    `uvm_component_utils(costas_top_sqr_class)

    function new(string name = "costas_top_sqr_class" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

endclass

endpackage
