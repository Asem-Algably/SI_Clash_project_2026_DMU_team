package costas_top_drive;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class costas_top_driver extends uvm_driver#(costas_top_seq_item);
        `uvm_component_utils(costas_top_driver)
        virtual costas_top_inter costas_top_test_vif;
        uvm_analysis_port #(costas_top_seq_item) drv_ap;

        function new(string name = "costas_top_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv_ap = new("drv_ap", this);
        endfunction

        task run_phase(uvm_phase phase);
            costas_top_seq_item item;
            forever begin
                seq_item_port.get_next_item(item);
                @(negedge costas_top_test_vif.clk);
                costas_top_test_vif.rst_n          <= item.rst_n;
                costas_top_test_vif.s_axis_valid_i <= item.valid;
                costas_top_test_vif.s_axis_i_sym_i <= item.i_sym;
                costas_top_test_vif.s_axis_q_sym_i <= item.q_sym;
                costas_top_test_vif.mode_i         <= item.mode;
                costas_top_test_vif.preamble_end_i <= item.preamble_end;
                costas_top_test_vif.mod_type_i     <= item.mod_type;
                costas_top_test_vif.slicer_qpsk_i  <= item.slicer_qpsk;
                costas_top_test_vif.costas_gain_i  <= item.costas_gain;
                if (item.exp_fval === 1'b1 || item.exp_pval === 1'b1) begin
                    drv_ap.write(item);
                end
                seq_item_port.item_done();
            end
        endtask
    endclass
endpackage