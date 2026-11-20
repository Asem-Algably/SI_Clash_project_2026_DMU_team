package str_top_drive;
    import uvm_pkg::*;
    import str_top_sequence_item::*;
    `include "uvm_macros.svh"

    class str_top_driver extends uvm_driver#(str_top_seq_item);
        `uvm_component_utils(str_top_driver)

        virtual str_top_inter str_top_test_vif;
        uvm_analysis_port #(str_top_seq_item) drv_ap;

        function new(string name = "str_top_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv_ap = new("drv_ap", this);
        endfunction

        // Safe idle values (no X on the DUT inputs)
        task drive_idle(logic rst);
            str_top_test_vif.rst_n             <= rst;
            str_top_test_vif.s_axis_valid_i    <= 1'b0;
            str_top_test_vif.flush_active_i    <= 1'b0;
            str_top_test_vif.s_axis_i_sample_i <= 12'd0;
            str_top_test_vif.s_axis_q_sample_i <= 12'd0;
            str_top_test_vif.loop_gain_i       <= 8'd0;
            str_top_test_vif.force_w_en_i      <= 1'b0;
            str_top_test_vif.force_w_i         <= 16'd0;
        endtask

        task run_phase(uvm_phase phase);
            str_top_seq_item item;

            drive_idle(1'b0);   // reset asserted from time 0

            forever begin
                seq_item_port.get_next_item(item);
                @(negedge str_top_test_vif.clk);

                str_top_test_vif.rst_n             <= item.rst_n;
                str_top_test_vif.s_axis_valid_i    <= item.valid;
                str_top_test_vif.flush_active_i    <= item.flush;
                str_top_test_vif.s_axis_i_sample_i <= item.i_in;
                str_top_test_vif.s_axis_q_sample_i <= item.q_in;
                str_top_test_vif.loop_gain_i       <= 8'd0;
                str_top_test_vif.force_w_en_i      <= 1'b0;
                str_top_test_vif.force_w_i         <= 16'd0;

                if (item.exp_valid === 1'b1)
                    drv_ap.write(item);

                seq_item_port.item_done();
            end
        endtask
    endclass
endpackage
