package str_top_monitor_pkg;
    import uvm_pkg::*;
    import str_top_sequence_item::*;
    `include "uvm_macros.svh"

    class str_top_monitor extends uvm_monitor;
        `uvm_component_utils(str_top_monitor)

        virtual str_top_inter str_top_test_vif;
        uvm_analysis_port #(str_top_seq_item) mon_ap;

        function new(string name = "str_top_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap", this);
        endfunction

        task run_phase(uvm_phase phase);
            str_top_seq_item item;
            forever begin
                @(negedge str_top_test_vif.clk);
                item = str_top_seq_item::type_id::create("item");

                item.m_axis_valid_o  = str_top_test_vif.m_axis_valid_o;
                item.m_axis_i_sym_o  = str_top_test_vif.m_axis_i_sym_o;
                item.m_axis_q_sym_o  = str_top_test_vif.m_axis_q_sym_o;
                item.lock_o          = str_top_test_vif.lock_o;
                item.ted_err_valid_o = str_top_test_vif.ted_err_valid_o;
                item.ted_err_o       = str_top_test_vif.ted_err_o;
                item.mu_o            = str_top_test_vif.mu_o;
                item.w_o             = str_top_test_vif.w_o;

                mon_ap.write(item);
            end
        endtask
    endclass
endpackage
