package coarse_cfo_core_monitor;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import coarse_cfo_core_sequence_item::*;

  class coarse_cfo_core_monitor extends uvm_monitor;
    `uvm_component_utils(coarse_cfo_core_monitor)

    coarse_cfo_core_seq_item item;
    virtual coarse_cfo_core_inter coarse_cfo_core_test_vif; // Name defined here
    uvm_analysis_port #(coarse_cfo_core_seq_item) mon_ap;

    function new(string name = "coarse_cfo_core_monitor",
                 uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon_ap = new("mon_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        // Use the correct name 'coarse_cfo_core_test_vif'
        @(posedge coarse_cfo_core_test_vif.clk);
        #1;
        
        item = coarse_cfo_core_seq_item::type_id::create("item");
        item.o_valid = coarse_cfo_core_test_vif.m_axis_valid_o;
        item.cfo     = coarse_cfo_core_test_vif.m_axis_cfo_o;
        mon_ap.write(item); // Send every cycle to cover both valid and invalid
      end
    endtask
  endclass
endpackage