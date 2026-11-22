package derotator_sequencer;
import uvm_pkg::*;
`include "uvm_macros.svh"
import derotator_sequence_item::*;
class derotator_sqr_class extends uvm_sequencer #(derotator_seq_item);
    `uvm_component_utils(derotator_sqr_class)

    function new(string name = "derotator_sqr_class" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

endclass

endpackage
