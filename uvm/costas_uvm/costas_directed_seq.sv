package directed_sequence;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class costas_directed_seq extends uvm_sequence#(costas_top_seq_item);
        `uvm_object_utils(costas_directed_seq)

        function new(string name = "costas_directed_seq");
            super.new(name);
        endfunction

        task body();
            costas_top_seq_item item;

            // 1. Get Lock first (to allow quad_check to start counting)
            for (int i = 0; i < 20; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 1; item.mode = 2'b01; item.mod_type = 2'b00; item.slicer_qpsk = 1;
                item.preamble_end = 0;
                item.i_sym = 16'sd16384; item.q_sym = 16'sd16384;
                finish_item(item);
            end

            // 2. Trigger Quad Unresolved (Equal positive and negative I/Q to zero out counters)
            for (int i = 0; i < 16; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 1; item.mode = 2'b01; item.slicer_qpsk = 1;
                // Alternate + and - to keep average at zero
                item.i_sym = (i % 2) ? 16'sd16384 : -16'sd16384;
                item.q_sym = (i % 2) ? 16'sd16384 : -16'sd16384;
                item.preamble_end = (i == 15); // Trigger at the exact zero point
                finish_item(item);
            end

            // 3. Trigger PI Filter Saturation & Phase Error Saturation
            for (int i = 0; i < 50; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 1; item.mode = 2'b01; item.mod_type = 2'b01; 
                item.slicer_qpsk = 0;
                item.preamble_end = 0;
                // Max amplitude signals to overflow the PI filter
                item.i_sym = (i % 2) ? 16'sh7FFF : -16'sh8000; 
                item.q_sym = (i % 2) ? 16'sh7FFF : -16'sh8000;
                finish_item(item);
            end

            // 4. Clean End: Drive zeros to remove the Red 'X' lines
            for (int i = 0; i < 20; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1; item.valid = 0; item.mode = 2'b00; 
                item.i_sym = 0; item.q_sym = 0; item.costas_gain = 0;
                item.preamble_end = 0;
                finish_item(item);
            end
        endtask
    endclass
endpackage