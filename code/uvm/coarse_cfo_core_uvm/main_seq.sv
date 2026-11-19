package main_sequence;
  import coarse_cfo_core_sequence_item::*;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class coarse_cfo_main_seq extends uvm_sequence#(coarse_cfo_core_seq_item);
    `uvm_object_utils(coarse_cfo_main_seq)

    rand int unsigned i_val    = 1000;  // I symbol value
    rand int unsigned q_val    = 0;     // Q symbol value
    rand int unsigned num_syms = 32;    // number of symbols
    rand int unsigned wait_cyc = 40;    // idle cycles after symbols

    function new(string name = "coarse_cfo_main_seq");
      super.new(name);
    endfunction

    task body();
      coarse_cfo_core_seq_item item;

      // 1) First symbol with start_i = 1 (rising edge trigger)
      item = coarse_cfo_core_seq_item::type_id::create("item");
      start_item(item);
      item.start     = 1;
      item.s_valid   = 1;
      item.i_sym     = i_val;
      item.q_sym     = q_val;
      item.force_en  = 0;
      item.force_val = 0;
      finish_item(item);

      // 2) Remaining 31 symbols (start_i = 0)
      for (int i = 1; i < num_syms; i++) begin
        item = coarse_cfo_core_seq_item::type_id::create("item");
        start_item(item);
        item.start     = 0;
        item.s_valid   = 1;
        item.i_sym     = i_val;
        item.q_sym     = q_val;
        item.force_en  = 0;
        item.force_val = 0;
        finish_item(item);
      end

      // 3) Idle cycles so accumulator+CORDIC finish
      for (int i = 0; i < wait_cyc; i++) begin
        item = coarse_cfo_core_seq_item::type_id::create("item");
        start_item(item);
        item.start     = 0;
        item.s_valid   = 0;
        item.i_sym     = 0;
        item.q_sym     = 0;
        item.force_en  = 0;
        item.force_val = 0;
        finish_item(item);
      end
    endtask
  endclass
endpackage