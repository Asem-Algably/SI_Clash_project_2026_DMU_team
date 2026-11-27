package coarse_cfo_core_drive;
  import uvm_pkg::*;
  import coarse_cfo_core_configuration::*;
  import coarse_cfo_core_sequence_item::*;
  `include "uvm_macros.svh"

  class coarse_cfo_core_driver extends uvm_driver#(coarse_cfo_core_seq_item);
    `uvm_component_utils(coarse_cfo_core_driver)

    coarse_cfo_core_seq_item item;
    virtual coarse_cfo_core_inter coarse_cfo_core_test_vif;
    uvm_analysis_port #(coarse_cfo_core_seq_item) drv_ap;

    function new(string name = "coarse_cfo_core_driver",
                 uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      drv_ap = new("drv_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
      super.run_phase(phase);
      forever begin
        seq_item_port.get_next_item(item);

        // Drive at negedge so signals are stable for DUT's posedge
        @(negedge coarse_cfo_core_test_vif.clk);

        coarse_cfo_core_test_vif.rst_ni         <= item.rst_ni;
        coarse_cfo_core_test_vif.start_i        <= item.start;
        coarse_cfo_core_test_vif.s_axis_valid_i <= item.s_valid;
        coarse_cfo_core_test_vif.s_axis_i_sym_i <= item.i_sym;
        coarse_cfo_core_test_vif.s_axis_q_sym_i <= item.q_sym;
        coarse_cfo_core_test_vif.force_cfo_en_i <= item.force_en;
        coarse_cfo_core_test_vif.force_cfo_i    <= item.force_val;

        if (item.exp_valid === 1'b1) begin
          drv_ap.write(item);
        end

        seq_item_port.item_done();
      end
    endtask
  endclass
endpackage