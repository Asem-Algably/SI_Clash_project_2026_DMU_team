`timescale 1ns/1ps

module top ();
    import uvm_pkg::*;
    import sync_system_top_test_pkg::*;
    `include "uvm_macros.svh"

    logic clk;

    // 125 MHz clock
    initial begin
        clk = 1'b0;
        forever #4 clk = ~clk;
    end

    // Interface. rst_n is driven by the UVM driver (reset_seq) through this interface.
    sync_system_top_inter sync_system_top_test_vif (clk);

    // DUT (default parameters = spec configuration)
    sync_system_top dut (
        .clk               (clk),
        .rst_n             (sync_system_top_test_vif.rst_n),
        .in_sample_i       (sync_system_top_test_vif.in_sample_i),
        .in_sample_q       (sync_system_top_test_vif.in_sample_q),
        .in_sample_valid   (sync_system_top_test_vif.in_sample_valid),
        .mod_type          (sync_system_top_test_vif.mod_type),
        .loop_gain         (sync_system_top_test_vif.loop_gain),
        .costas_loop_gain  (sync_system_top_test_vif.costas_loop_gain),
        .dft_sel           (sync_system_top_test_vif.dft_sel),
        .start_of_burst    (sync_system_top_test_vif.start_of_burst),
        .force_w_en        (sync_system_top_test_vif.force_w_en),
        .force_w           (sync_system_top_test_vif.force_w),
        .force_cfo_en      (sync_system_top_test_vif.force_cfo_en),
        .force_cfo         (sync_system_top_test_vif.force_cfo),
        .force_freq_en     (sync_system_top_test_vif.force_freq_en),
        .force_freq        (sync_system_top_test_vif.force_freq),
        .out_sym_i         (sync_system_top_test_vif.out_sym_i),
        .out_sym_q         (sync_system_top_test_vif.out_sym_q),
        .out_sym_valid     (sync_system_top_test_vif.out_sym_valid),
        .coarse_cfo_est    (sync_system_top_test_vif.coarse_cfo_est),
        .fine_cfo_est      (sync_system_top_test_vif.fine_cfo_est),
        .lock_detect       (sync_system_top_test_vif.lock_detect),
        .flush_active      (sync_system_top_test_vif.flush_active),
        .valid_during_flush(sync_system_top_test_vif.valid_during_flush),
        .dft_obs_data      (sync_system_top_test_vif.dft_obs_data)
    );

    // Internal taps (observation only)
    assign sync_system_top_test_vif.fsm_state    = dut.fsm_state;
    assign sync_system_top_test_vif.str_lock     = dut.str_lock;
    assign sync_system_top_test_vif.costas_lock  = dut.costas_lock;
    assign sync_system_top_test_vif.coarse_valid = dut.coarse_valid;
    assign sync_system_top_test_vif.str_valid    = dut.str_valid;

    // Assertions bound inside the DUT
    bind sync_system_top sva sva_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_sample_valid(in_sample_valid),
        .start_of_burst (start_of_burst),
        .out_sym_valid  (out_sym_valid),
        .out_sym_i      (out_sym_i),
        .out_sym_q      (out_sym_q),
        .lock_detect    (lock_detect),
        .str_lock       (str_lock),
        .costas_lock    (costas_lock),
        .flush_active   (flush_active),
        .fsm_state      (fsm_state)
    );

    initial begin
        uvm_config_db#(virtual sync_system_top_inter)::set(null, "*", "sync_system_top_test_vif", sync_system_top_test_vif);
        run_test("sync_system_top_test");
    end
endmodule
