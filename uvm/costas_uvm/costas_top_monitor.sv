package costas_top_monitor;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class costas_top_monitor extends uvm_monitor;
        `uvm_component_utils(costas_top_monitor)
        virtual costas_top_inter costas_top_test_vif;
        uvm_analysis_port #(costas_top_seq_item) mon_ap;

        function new(string name = "costas_top_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap", this);
        endfunction

        task run_phase(uvm_phase phase);
            costas_top_seq_item item;
            forever begin
                @(posedge costas_top_test_vif.clk);
                #1;
                item = costas_top_seq_item::type_id::create("item");
                // Inputs (needed by coverage)
                item.rst_n           = costas_top_test_vif.rst_n;
                item.valid           = costas_top_test_vif.s_axis_valid_i;
                item.i_sym           = costas_top_test_vif.s_axis_i_sym_i;
                item.q_sym           = costas_top_test_vif.s_axis_q_sym_i;
                item.mode            = costas_top_test_vif.mode_i;
                item.mod_type        = costas_top_test_vif.mod_type_i;
                item.slicer_qpsk     = costas_top_test_vif.slicer_qpsk_i;
                item.preamble_end    = costas_top_test_vif.preamble_end_i;
                // Observed internal/outputs
                item.kp              = costas_top_test_vif.kp_obs;
                item.e               = costas_top_test_vif.dbg_e_o;
                item.e_valid         = costas_top_test_vif.dbg_e_valid_o;
                item.freq_adj        = costas_top_test_vif.freq_adj_o;
                item.freq_adj_valid  = costas_top_test_vif.freq_adj_valid_o;
                item.int_val         = costas_top_test_vif.int_o;
                item.phase_adj       = costas_top_test_vif.phase_adj_o;
                item.phase_adj_valid = costas_top_test_vif.phase_adj_valid_o;
                item.lock            = costas_top_test_vif.lock_o;
                item.lock_int        = costas_top_test_vif.dbg_lock_int_o;
                item.quad_done       = costas_top_test_vif.dbg_quad_done_o;
                item.quad_unres      = costas_top_test_vif.quad_unresolved_o;
                mon_ap.write(item);
            end
        endtask
    endclass
endpackage