package str_top_sequence_item;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class str_top_seq_item extends uvm_sequence_item;
        `uvm_object_utils(str_top_seq_item)

        // Inputs driven to the DUT
        logic                    rst_n      = 1'b1;
        rand logic               valid      = 1'b0;
        rand logic signed [11:0] i_in       = '0;
        rand logic signed [11:0] q_in       = '0;
        rand logic               flush      = 1'b0;
        logic                    force_w_en = 1'b0;
        logic [15:0]             force_w    = 16'd0;

        // Expected outputs (from the golden vector file)
        logic                    exp_valid = 1'b0;
        logic signed [15:0]      exp_i     = '0;
        logic signed [15:0]      exp_q     = '0;
        logic                    exp_lock  = 1'b0;

        // Actual outputs (filled in by the monitor)
        logic                    m_axis_valid_o;
        logic signed [15:0]      m_axis_i_sym_o;
        logic signed [15:0]      m_axis_q_sym_o;
        logic                    lock_o;
        logic                    ted_err_valid_o;
        logic signed [31:0]      ted_err_o;
        logic [9:0]              mu_o;
        logic [15:0]             w_o;

        function new(string name = "str_top_seq_item");
            super.new(name);
        endfunction

        virtual function string convert2string();
            return $sformatf("rst_n=%0b valid=%0b flush=%0b in=(%0d,%0d) | exp_valid=%0b exp=(%0d,%0d) exp_lock=%0b | out_valid=%0b out=(%0d,%0d) lock=%0b",
                             rst_n, valid, flush, i_in, q_in,
                             exp_valid, exp_i, exp_q, exp_lock,
                             m_axis_valid_o, m_axis_i_sym_o, m_axis_q_sym_o, lock_o);
        endfunction
    endclass
endpackage
