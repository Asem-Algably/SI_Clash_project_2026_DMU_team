package sync_system_top_sequencer;
import uvm_pkg::*;
`include "uvm_macros.svh"
import sync_system_top_sequence_item::*;
class sync_system_top_sqr_class extends uvm_sequencer #(sync_system_top_seq_item);
    `uvm_component_utils(sync_system_top_sqr_class)

    function new(string name = "sync_system_top_sqr_class" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

endclass

endpackage
