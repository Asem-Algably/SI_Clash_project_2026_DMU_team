package reset_sequence;
    import uvm_pkg::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"

    class reset_seq extends uvm_sequence#(sync_system_top_seq_item);
        `uvm_object_utils(reset_seq)

        int unsigned num_reset_cycles = 5;
        int unsigned num_idle_cycles  = 2;

        function new(string name = "reset_seq");
            super.new(name);
        endfunction

        task body();
            sync_system_top_seq_item item;

            repeat (num_reset_cycles) begin
                item = sync_system_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n  = 1'b0;      // apply reset
                item.valid  = 1'b0;
                item.i_in   = 12'sd0;
                item.q_in   = 12'sd0;
                finish_item(item);
            end

            repeat (num_idle_cycles) begin
                item = sync_system_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n  = 1'b1;      // reset released, bus idle
                item.valid  = 1'b0;
                item.i_in   = 12'sd0;
                item.q_in   = 12'sd0;
                finish_item(item);
            end
        endtask
    endclass
endpackage
