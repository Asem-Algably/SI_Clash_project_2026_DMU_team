package main_sequence;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class costas_main_seq extends uvm_sequence#(costas_top_seq_item);
        `uvm_object_utils(costas_main_seq)

        function new(string name = "costas_main_seq");
            super.new(name);
        endfunction

        task body();
            costas_top_seq_item item;
            int qpsk_level = 16384;
            int qam_outer  = 16384;
            int qam_inner  = 5461;

            // 1. Start in HOLD Mode
            for (int i = 0; i < 5; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 0; item.mode = 2'b00; item.mod_type = 2'b00; item.slicer_qpsk = 1;
                finish_item(item);
            end

            // 2. ACQ Mode (QPSK Preamble)
            for (int i = 0; i < 50; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 1; item.mode = 2'b01; item.mod_type = 2'b00; item.slicer_qpsk = 1;
                item.preamble_end = (i == 49); // End of preamble
                item.i_sym = (i % 2) ? qpsk_level : -qpsk_level;
                item.q_sym = (i % 3) ? qpsk_level : -qpsk_level;
                finish_item(item);
            end

            // 3. TRACK Mode (16-QAM Payload)
            for (int i = 0; i < 100; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 1; item.mode = 2'b10; item.mod_type = 2'b01; item.slicer_qpsk = 0;
                item.preamble_end = 0;
                
                // Randomly pick one of the 4 levels for I and Q to cover all 16 points
                case (i % 4)
                    0: begin item.i_sym = qam_outer;  item.q_sym = qam_outer;  end
                    1: begin item.i_sym = qam_inner;  item.q_sym = -qam_inner; end
                    2: begin item.i_sym = -qam_inner; item.q_sym = qam_inner;  end
                    3: begin item.i_sym = -qam_outer; item.q_sym = -qam_outer; end
                endcase
                
                finish_item(item);
            end

            // 4. Valid Gap (Disconnect)
            for (int i = 0; i < 10; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 0; item.mode = 2'b10;
                finish_item(item);
            end
            
            // 5. Back to HOLD
            for (int i = 0; i < 5; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 0; item.mode = 2'b00;
                finish_item(item);
            end
        endtask
    endclass
endpackage