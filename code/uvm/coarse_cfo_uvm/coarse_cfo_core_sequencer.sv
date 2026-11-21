package coarse_cfo_core_sequencer;
import uvm_pkg::*;
`include "uvm_macros.svh"
import coarse_cfo_core_sequence_item::*;
class coarse_cfo_core_sqr_class extends uvm_sequencer #(coarse_cfo_core_seq_item);
    `uvm_component_utils(coarse_cfo_core_sqr_class)

    function new(string name = "coarse_cfo_core_sqr_class" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

endclass

endpackage
