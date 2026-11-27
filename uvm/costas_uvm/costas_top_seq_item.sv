package costas_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class costas_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(costas_top_seq_item)

        // Inputs
        logic               rst_n        = 1'b1;
        logic               valid        = 1'b0;
        logic signed [15:0] i_sym        = '0;
        logic signed [15:0] q_sym        = '0;
        logic [1:0]         mode         = 2'b00;
        logic               preamble_end = 1'b0;
        logic               slicer_qpsk  = 1'b1;
        logic [1:0]         mod_type     = 2'b00;
        logic [7:0]         costas_gain  = 8'd0;

        // Expected outputs (from golden file)
        logic               exp_fval     = 1'b0;
        logic signed [31:0] exp_freq_adj = '0;
        logic               exp_pval     = 1'b0;
        logic [31:0]        exp_phase_adj= '0;
        logic               exp_lock     = 1'b0;

        // Outputs & Internal Obs (Observed by Monitor)
        logic signed [15:0] e;
        logic               e_valid;
        logic signed [31:0] freq_adj, int_val;
        logic               freq_adj_valid;
        logic [31:0]        phase_adj;
        logic               phase_adj_valid;
        logic               lock, lock_int, quad_done, quad_unres;
        logic [23:0]        kp;

        function new(string name = "costas_top_seq_item");
            super.new(name);
        endfunction
    endclass
endpackage