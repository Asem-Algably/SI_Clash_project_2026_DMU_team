package reset_sequence;
import str_top_sequence_item::*;
import uvm_pkg::*;
`include "uvm_macros.svh"
class reset_seq extends uvm_sequence#(str_top_seq_item);
    `uvm_object_utils(reset_seq)
    str_top_seq_item item;
    function new(string name = "reset_seq");
        super.new(name);
    endfunction //new()
    task body();
        item = str_top_seq_item::type_id::create("item");
        start_item(item);
        // write the sequence
        finish_item(item);
    endtask
endclass //main_seq extends uvm_sequence
endpackage
