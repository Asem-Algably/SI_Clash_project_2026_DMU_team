package str_top_coverage_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import str_top_sequence_item::*;

    class str_top_cover extends uvm_component;
        `uvm_component_utils(str_top_cover)

        uvm_analysis_export #(str_top_seq_item)   cov_export;
        uvm_tlm_analysis_fifo #(str_top_seq_item) cov_fifo;
        str_top_seq_item item;

        covergroup g1;
            option.per_instance = 1;
            cp_out_valid : coverpoint item.m_axis_valid_o;
            cp_lock      : coverpoint item.lock_o;
            cp_ted_valid : coverpoint item.ted_err_valid_o;
            cp_mu        : coverpoint item.mu_o {
                bins q0 = {[0   : 255]};
                bins q1 = {[256 : 511]};
                bins q2 = {[512 : 767]};
                bins q3 = {[768 : 1023]};
            }
            cx_valid_lock : cross cp_out_valid, cp_lock;
        endgroup

        function new(string name = "str_top_cover", uvm_component parent = null);
            super.new(name, parent);
            g1 = new();
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
            end
        endtask
    endclass
endpackage
