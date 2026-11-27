package golden_sequence;
    import uvm_pkg::*;
    import coarse_cfo_core_sequence_item::*;
    `include "uvm_macros.svh"

    class golden_seq extends uvm_sequence#(coarse_cfo_core_seq_item);
        `uvm_object_utils(golden_seq)

        logic [67:0] vec_mem [0:20000]; 
        int num_vecs = 0;

        function new(string name = "golden_seq");
            super.new(name);
        endfunction

        task body();
            coarse_cfo_core_seq_item item;
            logic [3:0]  v_val;
            logic [15:0] i_sym;
            logic [15:0] q_sym;
            logic [3:0]  v_start;
            logic [3:0]  v_exp_val; 
            logic [23:0] exp_cfo;   
            
            // Just the filename since it's in the same folder
            string file_path = "tb_coarse_vec.hex";

            $readmemh(file_path, vec_mem);
            
            while (vec_mem[num_vecs] !== 68'hx && num_vecs < 20000) begin
                num_vecs++;
            end
            
            `uvm_info("GOLDEN_SEQ", $sformatf("Loaded %0d vectors from %s", num_vecs, file_path), UVM_LOW)

            if (num_vecs == 0) begin
                `uvm_fatal("GOLDEN_SEQ", "ERROR: File not found or empty! Check if the file name is exactly tb_coarse_vec.hex")
            end

            for (int i = 0; i < num_vecs; i++) begin
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item);
                
                {v_val, i_sym, q_sym, v_start, v_exp_val, exp_cfo} = vec_mem[i];
                
                item.start     = v_start[0];
                item.s_valid   = v_val[0];
                item.i_sym     = $signed(i_sym);
                item.q_sym     = $signed(q_sym);
                item.force_en  = 1'b0;
                item.force_val = 24'd0;
                
                finish_item(item);
            end

            for (int i = 0; i < 20; i++) begin
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item);
                item.start     = 1'b0; 
                item.s_valid   = 1'b0;
                item.i_sym     = 16'd0;
                item.q_sym     = 16'd0;
                item.force_en  = 1'b0;
                item.force_val = 24'd0;
                finish_item(item);
            end
        endtask
    endclass
endpackage