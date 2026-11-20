package golden_sequence;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class golden_seq extends uvm_sequence#(costas_top_seq_item);
        `uvm_object_utils(golden_seq)

        logic [123:0] vec_mem [0:20000];
        int num_vecs = 0;

        function new(string name = "golden_seq");
            super.new(name);
        endfunction

        task body();
            costas_top_seq_item item;
            logic [3:0] v_val, v_mode, v_pe, v_mod, v_exp_fval, v_exp_pval, v_exp_lock;
            logic signed [15:0] i_sym, q_sym;
            logic signed [31:0] exp_freq_adj;
            logic [31:0] exp_phase_adj;

            // Just the filename since it's in the same folder
            string file_path = "tb_costas_vec.hex";

            $readmemh(file_path, vec_mem);
            while (vec_mem[num_vecs] !== 124'hx && num_vecs < 20000) begin
                num_vecs++;
            end
            `uvm_info("GOLDEN_SEQ", $sformatf("Loaded %0d vectors from %s", num_vecs, file_path), UVM_LOW)

            if (num_vecs == 0) begin
                `uvm_fatal("GOLDEN_SEQ", "ERROR: File not found or empty! Put tb_costas_vec.hex in the current folder.")
            end

            for (int i = 0; i < num_vecs; i++) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                
                {v_val, i_sym, q_sym, v_mode, v_pe, v_mod, v_exp_fval, exp_freq_adj, v_exp_pval, exp_phase_adj, v_exp_lock} = vec_mem[i];
                
                item.rst_n          = 1'b1;
                item.valid          = v_val[0];
                item.i_sym          = i_sym;
                item.q_sym          = q_sym;
                item.mode           = v_mode[1:0];
                item.preamble_end   = v_pe[0];
                item.mod_type       = v_mod[1:0];
                item.slicer_qpsk    = (item.mode != 2'b10);
                item.costas_gain    = 8'd0;

                finish_item(item);
            end
        endtask
    endclass
endpackage