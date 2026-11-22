package derotator_golden_seq_pkg;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"

    class derotator_golden_seq extends uvm_sequence#(derotator_seq_item);
        `uvm_object_utils(derotator_golden_seq)

        // Assuming a 192-bit vector based on standard packing
        logic [191:0] vec_mem [0:20000];
        int num_vecs = 0;

        function new(string name = "derotator_golden_seq");
            super.new(name);
        endfunction

        task body();
            derotator_seq_item item;
            
            // Variables for unpacking
            logic        v_s_axis_valid, v_coarse_valid, v_freq_adj_valid;
            logic        v_force_freq_en, v_phase_adj_valid;
            logic signed [15:0] i_sym, q_sym;
            logic signed [23:0] coarse_word;
            logic signed [31:0] freq_adj, force_freq, phase_adj;
            logic signed [15:0] exp_i, exp_q;

            // Just the filename since it's in the same folder
            string file_path = "tb_derot_vec.hex";

            $readmemh(file_path, vec_mem);
            
            // Find how many valid vectors in the file
            while (vec_mem[num_vecs] !== 192'hx && num_vecs < 20000) begin
                num_vecs++;
            end
            
            `uvm_info("GOLDEN_SEQ", $sformatf("Loaded %0d vectors from %s", num_vecs, file_path), UVM_LOW)

            if (num_vecs == 0) begin
                `uvm_fatal("GOLDEN_SEQ", "ERROR: File not found or empty! Put tb_derot_vec.hex in the current folder.")
            end

            for (int i = 0; i < num_vecs; i++) begin
                item = derotator_seq_item::type_id::create("item");
                start_item(item);
                
                // IMPORTANT: Adjust this concatenation to match your HEX file layout!
                { 
                    v_s_axis_valid, 
                    i_sym, 
                    q_sym, 
                    v_coarse_valid, 
                    coarse_word, 
                    v_freq_adj_valid, 
                    freq_adj, 
                    v_force_freq_en, 
                    force_freq, 
                    v_phase_adj_valid, 
                    phase_adj, 
                    exp_i, 
                    exp_q 
                } = vec_mem[i];
                
                // Map inputs
                item.rst_ni             = 1'b1;
                item.s_axis_valid_i     = v_s_axis_valid;
                item.s_axis_i_sym_i     = i_sym;
                item.s_axis_q_sym_i     = q_sym;
                item.coarse_valid_i     = v_coarse_valid;
                item.coarse_word_i      = coarse_word;
                item.freq_adj_valid_i   = v_freq_adj_valid;
                item.freq_adj_i         = freq_adj;
                item.force_freq_en_i    = v_force_freq_en;
                item.force_freq_i       = force_freq;
                item.phase_adj_valid_i  = v_phase_adj_valid;
                item.phase_adj_i        = phase_adj;
                
                // Map Expected Outputs
                item.exp_i              = exp_i;
                item.exp_q              = exp_q;

                finish_item(item);
            end
        endtask
    endclass
endpackage