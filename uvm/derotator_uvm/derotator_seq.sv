package derotator_sequence_pkg;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"

    class derotator_seq extends uvm_sequence #(derotator_seq_item);
        `uvm_object_utils(derotator_seq)
        
        function new(string name = "derotator_seq");
            super.new(name);
        endfunction

        task body();
            derotator_seq_item req;
            integer file;
            integer status;
            
            // Open the hex file directly (no path)
            file = $fopen("tb_derot_vec.hex", "r");
            if (file == 0) begin
                `uvm_fatal("SEQ", "Could not open tb_derot_vec.hex")
            end

            // Read line by line
            // Adjust the format specifier based on your actual hex file structure
            while (!$feof(file)) begin
                req = derotator_seq_item::type_id::create("req");
                start_item(req);
                
                // Example: Reads I_in, Q_in, Exp_I, Exp_Q (Hex format)
                status = $fscanf(file, "%h %h %h %h\n", req.s_axis_i_sym_i, req.s_axis_q_sym_i, req.exp_i, req.exp_q);
                
                if (status == 4) begin
                    // Static configurations for the vector test
                    req.s_axis_valid_i = 1;
                    req.coarse_valid_i = 0;
                    req.freq_adj_valid_i = 0;
                    req.phase_adj_valid_i = 0;
                    req.force_freq_en_i = 0;
                    
                    finish_item(req);
                end
            end
            $fclose(file);
        endtask
    endclass
endpackage