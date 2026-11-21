package main_sequence;
    import uvm_pkg::*;
    import str_top_sequence_item::*;
    `include "uvm_macros.svh"

    class str_main_seq extends uvm_sequence#(str_top_seq_item);
        `uvm_object_utils(str_main_seq)

        int unsigned num_samples = 2000;   // 500 symbols * 4 samples/symbol
        int unsigned num_idle    = 20;

        function new(string name = "str_main_seq");
            super.new(name);
        endfunction

        task body();
            str_top_seq_item    item;
            logic signed [11:0] qpsk_i [4];
            logic signed [11:0] qpsk_q [4];
            int                 sym_idx;

            qpsk_i[0] =  12'sd1000;  qpsk_q[0] =  12'sd1000;
            qpsk_i[1] = -12'sd1000;  qpsk_q[1] =  12'sd1000;
            qpsk_i[2] = -12'sd1000;  qpsk_q[2] = -12'sd1000;
            qpsk_i[3] =  12'sd1000;  qpsk_q[3] = -12'sd1000;
            sym_idx   = 0;

            for (int i = 0; i < num_samples; i++) begin
                item = str_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b1;
                item.valid = 1'b1;
                item.flush = 1'b0;
                item.i_in  = qpsk_i[sym_idx];
                item.q_in  = qpsk_q[sym_idx];
                if (i % 4 == 3) sym_idx = (sym_idx + 1) % 4;
                finish_item(item);
            end

            // End of burst: idle
            for (int i = 0; i < num_idle; i++) begin
                item = str_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b1;
                item.valid = 1'b0;
                item.flush = 1'b0;
                item.i_in  = 12'sd0;
                item.q_in  = 12'sd0;
                finish_item(item);
            end
        endtask
    endclass
endpackage
