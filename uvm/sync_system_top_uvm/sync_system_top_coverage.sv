package sync_system_top_coverage_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import sync_system_top_sequence_item::*;

    class sync_system_top_cover extends uvm_component;
        `uvm_component_utils(sync_system_top_cover)

        uvm_analysis_export #(sync_system_top_seq_item)   cov_export;
        uvm_tlm_analysis_fifo #(sync_system_top_seq_item) cov_fifo;
        sync_system_top_seq_item item;
        logic [2:0] prev_fsm_state = 3'd0;
        bit         has_prev_state = 1'b0;

        covergroup g1;
            option.per_instance = 1;

            cp_state : coverpoint item.fsm_state {
                bins wait_burst = {0};
                bins acquire    = {1};
                bins coarse_est = {2};
                bins load       = {3};
                bins costas_acq = {4};
                bins track      = {5};
                bins flush      = {6};
                illegal_bins bad = {7};
            }
            cp_mod_type  : coverpoint item.mod_type {
                bins qpsk  = {2'b00};
                bins qam16 = {2'b01};
            }
            cp_mod_trans : coverpoint item.mod_type {
                bins qpsk_to_qam = (2'b00 => 2'b01);
                bins qam_to_qpsk = (2'b01 => 2'b00);
            }
            cp_out_valid : coverpoint item.out_sym_valid;
            cp_lock      : coverpoint item.lock_detect;
            cp_str_lock  : coverpoint item.str_lock;
            cp_cos_lock  : coverpoint item.costas_lock;
            cp_flush     : coverpoint item.flush_active;
            cp_in_valid  : coverpoint item.valid;
            cp_dft_sel   : coverpoint item.dft_sel;
            cp_force_w   : coverpoint item.force_w_en;
            cp_force_cfo : coverpoint item.force_cfo_en;
            cp_force_frq : coverpoint item.force_freq_en;
            cp_cfo_sign  : coverpoint item.coarse_cfo_est[23] iff (item.fsm_state >= 4) {
                bins positive = {0};
                bins negative = {1};
            }

            cx_state_valid : cross cp_state, cp_out_valid {
                ignore_bins impossible_early_valid =
                    (binsof(cp_state) intersect {0, 1, 2, 3}) && binsof(cp_out_valid) intersect {1};
            }
            cx_state_lock  : cross cp_state, cp_lock {
                ignore_bins impossible_early_lock =
                    (binsof(cp_state) intersect {0, 1, 2, 3, 4}) && binsof(cp_lock) intersect {1};
            }
            cx_mod_state   : cross cp_mod_type, cp_state;
            cx_dft_state   : cross cp_dft_sel, cp_state;
        endgroup

        // Sample multi-clock FSM state transitions only when fsm_state changes
        covergroup g_fsm_trans;
            option.per_instance = 1;
            cp_state_trans : coverpoint item.fsm_state {
                bins full_burst = (0 => 1 => 2 => 3 => 4 => 5 => 6 => 0);
                bins early_lock = (1 => 2);
                bins coarse_dir = (2 => 4);
                bins watchdog   = (1, 2, 3, 4, 5 => 6);
            }
        endgroup

        function new(string name = "sync_system_top_cover", uvm_component parent = null);
            super.new(name, parent);
            g1          = new();
            g_fsm_trans = new();
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            cov_export = new("cov_export", this);
            cov_fifo   = new("cov_fifo", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            cov_export.connect(cov_fifo.analysis_export);
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                cov_fifo.get(item);
                g1.sample();
                if (!has_prev_state || (item.fsm_state !== prev_fsm_state)) begin
                    g_fsm_trans.sample();
                    prev_fsm_state = item.fsm_state;
                    has_prev_state = 1'b1;
                end
            end
        endtask
    endclass
endpackage
