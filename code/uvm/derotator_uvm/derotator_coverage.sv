package derotator_coverage_pkg;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"
    
    class derotator_cover extends uvm_component;
        `uvm_component_utils(derotator_cover)
        uvm_analysis_export #(derotator_seq_item) cov_export;
        uvm_tlm_analysis_fifo #(derotator_seq_item) cov_fifo;
        derotator_seq_item item;

        // متغيرات مساعدة للتغطية
        logic [1:0] quad_pipe[$];
        logic [1:0] out_quad;

        covergroup cg_in_valid;
            cp_valid: coverpoint item.s_axis_valid_i {
                bins v_1 = {1}; bins v_0 = {0};
                bins gap_to_valid = (0 => 1); bins valid_to_gap = (1 => 0);
            }
        endgroup

        covergroup cg_nco;
            cp_quad: coverpoint item.phase_o[31:30] iff (item.s_axis_valid_i) {
                bins q0 = {0}; bins q1 = {1}; bins q2 = {2}; bins q3 = {3};
            }
        endgroup

        covergroup cg_input_sym;
            cp_sign: coverpoint {item.s_axis_i_sym_i[15], item.s_axis_q_sym_i[15]} iff (item.s_axis_valid_i) {
                bins Q1 = {2'b00}; bins Q2 = {2'b10}; bins Q3 = {2'b11}; bins Q4 = {2'b01};
            }
        endgroup

        covergroup cg_freq;
            cp_force: coverpoint item.force_freq_en_i {
                bins off = {0}; bins on = {1};
            }
        endgroup

        covergroup cg_output;
            cp_mv: coverpoint item.m_axis_valid_o {
                bins v_1 = {1}; bins v_0 = {0};
            }
            cp_osign: coverpoint {item.m_axis_i_sym_o[15], item.m_axis_q_sym_o[15]} iff (item.m_axis_valid_o) {
                bins Q1 = {2'b00}; bins Q2 = {2'b10}; bins Q3 = {2'b11}; bins Q4 = {2'b01};
            }
        endgroup

        function new(string name = "derotator_cover" , uvm_component parent = null);
            super.new(name,parent);
            cg_in_valid = new();
            cg_nco = new();
            cg_input_sym = new();
            cg_freq = new();
            cg_output = new();
        endfunction

        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            cov_export = new("cov_export",this);
            cov_fifo = new("cov_fifo",this);
        endfunction

        function void connect_phase (uvm_phase phase);
            super.connect_phase(phase);
            cov_export.connect(cov_fifo.analysis_export);
        endfunction
        
        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                cov_fifo.get(item);
                
                // Sample Covergroups
                cg_in_valid.sample();
                cg_nco.sample();
                cg_input_sym.sample();
                cg_freq.sample();
                cg_output.sample();
            end
        endtask

        function void report_phase(uvm_phase phase);
            `uvm_info("COV", "======== DEROTATOR COVERAGE ========", UVM_LOW)
            `uvm_info("COV", $sformatf(" cg_in_valid  : %6.2f %%", cg_in_valid.get_inst_coverage()), UVM_LOW)
            `uvm_info("COV", $sformatf(" cg_nco       : %6.2f %%", cg_nco.get_inst_coverage()), UVM_LOW)
            `uvm_info("COV", $sformatf(" cg_input_sym : %6.2f %%", cg_input_sym.get_inst_coverage()), UVM_LOW)
            `uvm_info("COV", $sformatf(" cg_freq      : %6.2f %%", cg_freq.get_inst_coverage()), UVM_LOW)
            `uvm_info("COV", $sformatf(" cg_output    : %6.2f %%", cg_output.get_inst_coverage()), UVM_LOW)
        endfunction
    endclass
endpackage