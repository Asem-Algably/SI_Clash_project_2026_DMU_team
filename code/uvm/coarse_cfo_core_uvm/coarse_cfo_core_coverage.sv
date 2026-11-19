package coarse_cfo_core_coverage_pkg;
    import uvm_pkg::*;
    import coarse_cfo_core_sequence_item::*;
    `include "uvm_macros.svh"

    class coarse_cfo_core_cover extends uvm_component;
        `uvm_component_utils(coarse_cfo_core_cover)

        uvm_analysis_export #(coarse_cfo_core_seq_item) cov_export;
        uvm_tlm_analysis_fifo #(coarse_cfo_core_seq_item) cov_fifo;
        coarse_cfo_core_seq_item item;

        covergroup g1;
            cp_valid: coverpoint item.o_valid {
                bins valid   = {1};
                bins invalid = {0};
            }
            cp_cfo: coverpoint item.cfo {
                bins zero       = {0};
                bins small_pos  = {[1:100000]};
                bins small_neg  = {[-100000:-1]};
                bins large_pos  = {[100001:8388607]};
                bins large_neg  = {[-8388608:-100001]};
            }
        endgroup

        function new(string name = "coarse_cfo_core_cover", uvm_component parent = null);
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