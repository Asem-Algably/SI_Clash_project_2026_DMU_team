package sync_system_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class sync_system_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(sync_system_top_seq_item)

        // ------------- Inputs driven to the DUT -------------
        logic                    rst_n          = 1'b1;
        rand logic               valid          = 1'b0;
        rand logic signed [11:0] i_in           = '0;
        rand logic signed [11:0] q_in           = '0;
        logic [1:0]              mod_type       = 2'b01;     // 00 = QPSK, 01 = 16-QAM
        logic [7:0]              loop_gain      = 8'd0;
        logic [7:0]              costas_gain    = 8'd0;
        logic [3:0]              dft_sel        = 4'd0;
        logic                    force_w_en     = 1'b0;
        logic [15:0]             force_w        = '0;
        logic                    force_cfo_en   = 1'b0;
        logic signed [23:0]      force_cfo      = '0;
        logic                    force_freq_en  = 1'b0;
        logic [31:0]             force_freq     = '0;

        // ------------- Expected values (from tb_top_tc_XX.hex / tb_top_vec.hex) -------------
        bit                      golden         = 1'b0;      // item comes from the golden file
        logic                    exp_valid      = 1'b0;
        logic signed [15:0]      exp_i          = '0;
        logic signed [15:0]      exp_q          = '0;
        logic [2:0]              exp_state      = '0;
        logic                    exp_lock       = 1'b0;
        bit                      has_exp_cfo    = 1'b0;
        logic signed [23:0]      exp_cfo        = '0;

        // ------------- Actual outputs (filled in by the monitor) -------------
        logic                    out_sym_valid;
        logic signed [15:0]      out_sym_i;
        logic signed [15:0]      out_sym_q;
        logic signed [23:0]      coarse_cfo_est;
        logic signed [31:0]      fine_cfo_est;
        logic                    lock_detect;
        logic                    flush_active;
        logic [7:0]              valid_during_flush;
        logic [31:0]             dft_obs_data;
        logic [2:0]              fsm_state;
        logic                    str_lock;
        logic                    costas_lock;
        logic                    coarse_valid;
        logic                    str_valid;

        function new(string name = "sync_system_top_seq_item");
            super.new(name);
        endfunction

        virtual function string convert2string();
            return $sformatf("rst_n=%0b valid=%0b in=(%0d,%0d) | exp_valid=%0b exp=(%0d,%0d) exp_state=%0d exp_lock=%0b | out_valid=%0b out=(%0d,%0d) state=%0d lock=%0b",
                             rst_n, valid, i_in, q_in,
                             exp_valid, exp_i, exp_q, exp_state, exp_lock,
                             out_sym_valid, out_sym_i, out_sym_q, fsm_state, lock_detect);
        endfunction
    endclass
endpackage
