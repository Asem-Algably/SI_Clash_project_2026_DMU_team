package reset_sequence;
  import coarse_cfo_core_sequence_item::*;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class reset_seq extends uvm_sequence#(coarse_cfo_core_seq_item);
    `uvm_object_utils(reset_seq)

    function new(string name = "reset_seq");
      super.new(name);
    endfunction

    task body();
      coarse_cfo_core_seq_item item;
      repeat (5) begin
        item = coarse_cfo_core_seq_item::type_id::create("item");
        start_item(item);
        item.rst_ni    = 1'b0;
        item.start     = 0; item.s_valid = 0; item.i_sym = 0; item.q_sym = 0;
        item.force_en  = 0; item.force_val = 0; item.exp_valid = 0;
        finish_item(item);
      end
      repeat (2) begin
        item = coarse_cfo_core_seq_item::type_id::create("item");
        start_item(item);
        item.rst_ni    = 1'b1;
        item.start     = 0; item.s_valid = 0; item.i_sym = 0; item.q_sym = 0;
        item.force_en  = 0; item.force_val = 0; item.exp_valid = 0;
        finish_item(item);
      end
    endtask
  endclass
endpackage