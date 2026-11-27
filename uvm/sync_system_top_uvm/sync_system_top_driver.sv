package sync_system_top_drive;
    import uvm_pkg::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"

    class sync_system_top_driver extends uvm_driver#(sync_system_top_seq_item);
        `uvm_component_utils(sync_system_top_driver)

        virtual sync_system_top_inter sync_system_top_test_vif;

        uvm_analysis_port #(sync_system_top_seq_item) drv_ap;   // expected output symbols
        uvm_analysis_port #(sync_system_top_seq_item) st_ap;    // expected FSM state changes

        logic [2:0] prev_exp_state = 3'd0;    // FSM sits in WaitBurst after reset

        function new(string name = "sync_system_top_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv_ap = new("drv_ap", this);
            st_ap  = new("st_ap",  this);
        endfunction

        // Safe idle values (no X on the DUT inputs)
        task drive_idle(logic rst);
            sync_system_top_test_vif.rst_n            <= rst;
            sync_system_top_test_vif.in_sample_valid  <= 1'b0;
            sync_system_top_test_vif.in_sample_i      <= 12'sd0;
            sync_system_top_test_vif.in_sample_q      <= 12'sd0;
            sync_system_top_test_vif.mod_type         <= 2'b00;
            sync_system_top_test_vif.loop_gain        <= 8'd0;
            sync_system_top_test_vif.costas_loop_gain <= 8'd0;
            sync_system_top_test_vif.dft_sel          <= 4'd0;
            sync_system_top_test_vif.force_w_en       <= 1'b0;
            sync_system_top_test_vif.force_w          <= 16'd0;
            sync_system_top_test_vif.force_cfo_en     <= 1'b0;
            sync_system_top_test_vif.force_cfo        <= 24'sd0;
            sync_system_top_test_vif.force_freq_en    <= 1'b0;
            sync_system_top_test_vif.force_freq       <= 32'd0;
        endtask

        task run_phase(uvm_phase phase);
            sync_system_top_seq_item item;

            drive_idle(1'b0);   // reset asserted from time 0

            forever begin
                seq_item_port.get_next_item(item);
                @(negedge sync_system_top_test_vif.clk);

                sync_system_top_test_vif.rst_n            <= item.rst_n;
                sync_system_top_test_vif.in_sample_valid  <= item.valid;
                sync_system_top_test_vif.in_sample_i      <= item.i_in;
                sync_system_top_test_vif.in_sample_q      <= item.q_in;
                sync_system_top_test_vif.mod_type         <= item.mod_type;
                sync_system_top_test_vif.loop_gain        <= item.loop_gain;
                sync_system_top_test_vif.costas_loop_gain <= item.costas_gain;
                sync_system_top_test_vif.dft_sel          <= item.dft_sel;
                sync_system_top_test_vif.force_w_en       <= item.force_w_en;
                sync_system_top_test_vif.force_w          <= item.force_w;
                sync_system_top_test_vif.force_cfo_en     <= item.force_cfo_en;
                sync_system_top_test_vif.force_cfo        <= item.force_cfo;
                sync_system_top_test_vif.force_freq_en    <= item.force_freq_en;
                sync_system_top_test_vif.force_freq       <= item.force_freq;

                if (item.golden) begin
                    if (item.exp_valid === 1'b1)
                        drv_ap.write(item);                    // expected output symbol
                    if (item.exp_state !== prev_exp_state) begin
                        st_ap.write(item);                     // expected FSM state change
                        prev_exp_state = item.exp_state;
                    end
                end

                seq_item_port.item_done();
            end
        endtask
    endclass
endpackage
