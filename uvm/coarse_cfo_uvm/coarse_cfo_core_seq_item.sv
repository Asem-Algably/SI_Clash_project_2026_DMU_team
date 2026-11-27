package coarse_cfo_core_sequence_item;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class coarse_cfo_core_seq_item extends uvm_sequence_item;
    `uvm_object_utils(coarse_cfo_core_seq_item)

    // Stimulus fields (driven by driver)
    logic                    rst_ni    = 1'b1;
    rand logic               start     = 1'b0;
    rand logic               s_valid   = 1'b0;
    rand logic signed [15:0] i_sym     = '0;
    rand logic signed [15:0] q_sym     = '0;
    rand logic               force_en  = 1'b0;
    rand logic [23:0]        force_val = '0;

    // Expected fields (from golden file)
    logic                    exp_valid = 1'b0;
    logic signed [23:0]      exp_cfo   = '0;

    // Observation fields (sampled by monitor)
    logic               o_valid;
    logic signed [23:0] cfo;

    function new(string name = "coarse_cfo_core_seq_item");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("start=%0b s_valid=%0b i=%0d q=%0d o_valid=%0b cfo=%0d",
                       start, s_valid, i_sym, q_sym, o_valid, cfo);
    endfunction
  endclass
endpackage