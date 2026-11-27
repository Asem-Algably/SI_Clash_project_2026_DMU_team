package reset_sequence;
    import costas_top_sequence_item::*;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class reset_seq extends uvm_sequence#(costas_top_seq_item);
        `uvm_object_utils(reset_seq)

        function new(string name = "reset_seq");
            super.new(name);
        endfunction

        task body();
            costas_top_seq_item item;
            
            // Drive reset followed by clean idle cycles before golden sequence
            repeat (5) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n        = 1'b0;
                item.valid        = 1'b0;
                item.i_sym        = 16'd0;
                item.q_sym        = 16'd0;
                item.mode         = 2'b00;
                item.preamble_end = 1'b0;
                item.mod_type     = 2'b00;
                item.slicer_qpsk  = 1'b1;
                item.costas_gain  = 8'd0;
                finish_item(item);
            end
            repeat (2) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n        = 1'b1;
                item.valid        = 1'b0;
                item.i_sym        = 16'd0;
                item.q_sym        = 16'd0;
                item.mode         = 2'b00;
                item.preamble_end = 1'b0;
                item.mod_type     = 2'b00;
                item.slicer_qpsk  = 1'b1;
                item.costas_gain  = 8'd0;
                finish_item(item);
            end
        endtask
    endclass
endpackage