package str_top_coverage_pkg;
import uvm_pkg::*;
`include "uvm_macros.svh"
import str_top_sequence_item::*;
class str_top_cover extends uvm_component;
`uvm_component_utils(str_top_cover)
uvm_analysis_export #(str_top_seq_item) cov_export;
uvm_tlm_analysis_fifo #(str_top_seq_item) cov_fifo;
str_top_seq_item item;
parameter maxpos=3, maxneg=-4, zero=0 ;
covergroup g1 ;
        // coverage functions
        endgroup

   function new(string name = "str_top_cover" , uvm_component parent = null);
        super.new(name,parent);
        g1=new();
    endfunction

      function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        cov_export=new("sb_export",this);
        cov_fifo=new("sb_fifo",this);
    endfunction

    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        cov_export.connect(cov_fifo.analysis_export);
    endfunction
     task  run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
        cov_fifo.get(item);
        g1.sample();
        end
    endtask
endclass

endpackage
