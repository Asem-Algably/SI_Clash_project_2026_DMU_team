package main_sequence;
    import uvm_pkg::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"

    // Directed smoke test (no golden checking): two bursts of a QPSK-like pattern,
    // DFT channel sweep, force-override exercise, idle gap that triggers the watchdog flush.
    class sync_main_seq extends uvm_sequence#(sync_system_top_seq_item);
        `uvm_object_utils(sync_main_seq)

        int unsigned num_samples = 800;   // 200 symbols * 4 samples/symbol
        int unsigned num_idle    = 40;    // > 14 (idle watchdog) + 16 (flush clocks)
        logic [1:0]  mod_type    = 2'b00;

        function new(string name = "sync_main_seq");
            super.new(name);
        endfunction

        task send(bit v, int i, int q, bit [3:0] dsel,
                  bit fw = 0, logic [15:0] fw_val = 16'h1000,
                  bit fc = 0, logic signed [23:0] fc_val = 24'sd100000,
                  bit ff = 0, logic [31:0] ff_val = 32'h0010_0000);
            sync_system_top_seq_item item;
            item = sync_system_top_seq_item::type_id::create("item");
            start_item(item);
            item.rst_n         = 1'b1;
            item.valid         = v;
            item.i_in          = i;
            item.q_in          = q;
            item.mod_type      = mod_type;
            item.dft_sel       = dsel;
            item.force_w_en    = fw;
            item.force_w       = fw_val;
            item.force_cfo_en  = fc;
            item.force_cfo     = fc_val;
            item.force_freq_en = ff;
            item.force_freq    = ff_val;
            finish_item(item);
        endtask

        task burst(bit use_force);
            logic signed [11:0] qpsk_i [4];
            logic signed [11:0] qpsk_q [4];
            logic [15:0]        fw_val;
            logic signed [23:0] fc_val;
            logic [31:0]        ff_val;
            bit                 fw, fc, ff;
            int sym_idx;

            sym_idx   = 0;
            qpsk_i[0] =  12'sd1000;  qpsk_q[0] =  12'sd1000;
            qpsk_i[1] = -12'sd1000;  qpsk_q[1] =  12'sd1000;
            qpsk_i[2] = -12'sd1000;  qpsk_q[2] = -12'sd1000;
            qpsk_i[3] =  12'sd1000;  qpsk_q[3] = -12'sd1000;

            for (int n = 0; n < num_samples; n++) begin
                fw     = use_force && (n > 100 && n < 200);
                fw_val = (n < 150) ? 16'h2000 : 16'h6000; // Slow & fast STR NCO override
                fc     = use_force && ((n == 450) || (n >= 470 && n < 500)); // 1-cycle pulse & held post-acq
                fc_val = (n == 450) ? 24'sd250000 : -24'sd180000;
                ff     = use_force && (n > 550 && n < 680);
                ff_val = (n < 615) ? 32'h0010_0000 : 32'hFFE0_0000;
                send(1'b1, qpsk_i[sym_idx], qpsk_q[sym_idx], (n / 4) % 16,
                     fw, fw_val, fc, fc_val, ff, ff_val);
                if (n % 4 == 3) sym_idx = (sym_idx + 1) % 4;
            end
            repeat (num_idle) send(1'b0, 0, 0, 4'd0);
        endtask

        task body();
            burst(1'b0);   // plain burst
            burst(1'b1);   // burst with force overrides
        endtask
    endclass
endpackage
