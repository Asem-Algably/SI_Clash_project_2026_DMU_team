package costas_top_coverage_pkg;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    import costas_pkg::*;
    `include "uvm_macros.svh"

    class costas_top_cover extends uvm_component;
        `uvm_component_utils(costas_top_cover)

        uvm_analysis_export #(costas_top_seq_item) cov_export;
        uvm_tlm_analysis_fifo #(costas_top_seq_item) cov_fifo;
        costas_top_seq_item item;
        
        // Instantiate Golden Model Transaction for Coverage
        costas_transaction tr;

        function new(string name = "costas_top_cover", uvm_component parent = null);
            super.new(name, parent);
            tr = new();
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
                
                // Map UVM item to Golden Model Transaction
                tr.mode = mode_e'(item.mode);
                tr.mod_type = (item.mod_type == 2'b01) ? QAM16 : QPSK;
                tr.valid = item.valid;
                tr.i_sym = item.i_sym;
                tr.q_sym = item.q_sym;
                tr.preamble_end = item.preamble_end;
                tr.slicer_qpsk = item.slicer_qpsk;
                tr.sample_in();
                
                tr.e = item.e;
                tr.e_valid = item.e_valid;
                tr.freq_adj = item.freq_adj;
                tr.freq_adj_valid = item.freq_adj_valid;
                tr.int_val = item.int_val;
                tr.phase_adj = item.phase_adj;
                tr.phase_adj_valid = item.phase_adj_valid;
                tr.lock = item.lock;
                tr.lock_int = item.lock_int;
                tr.quad_done = item.quad_done;
                tr.quad_unres = item.quad_unres;
                tr.kp = 24'd220364; // Dummy kp for coverage (or fetch from interface if needed)
                tr.sample_out();
            end
        endtask
    endclass
endpackage