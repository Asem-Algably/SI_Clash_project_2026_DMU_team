package costas_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class costas_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(costas_top_seq_item)

        // Inputs
        logic               rst_n;
        logic               valid;
        logic signed [15:0] i_sym, q_sym;
        logic [1:0]         mode;
        logic               preamble_end, slicer_qpsk;
        logic [1:0]         mod_type;
        logic [7:0]         costas_gain;

        // Outputs (Observed by Monitor)
        logic signed [15:0] e;
        logic               e_valid;
        logic signed [31:0] freq_adj, int_val;
        logic               freq_adj_valid;
        logic [31:0]        phase_adj;
        logic               phase_adj_valid;
        logic               lock, lock_int, quad_done, quad_unres;

        function new(string name = "costas_top_seq_item");
            super.new(name);
        endfunction
    endclass
endpackage