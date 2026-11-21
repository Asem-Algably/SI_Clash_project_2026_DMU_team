package directed_sequence;
    import uvm_pkg::*;
    import coarse_cfo_core_sequence_item::*;
    `include "uvm_macros.svh"

    class directed_cfo_seq extends uvm_sequence#(coarse_cfo_core_seq_item);
        `uvm_object_utils(directed_cfo_seq)

        function new(string name = "directed_cfo_seq");
            super.new(name);
        endfunction

        task body();
            coarse_cfo_core_seq_item item;
            real phase;
            int i_val, q_val;
            
            // Coverage targets: 0.005 (small_pos), -0.01 (small_neg), -0.25 (large_neg)
            real cfo_targets[] = '{0.005, -0.01, -0.25};

            foreach (cfo_targets[i]) begin
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item);
                item.start = 1; item.s_valid = 1; item.i_sym = 10000; item.q_sym = 0; item.force_en = 0; item.force_val = 0;
                finish_item(item);

                for (int n = 1; n < 32; n++) begin
                    phase = 2.0 * 3.1415926535 * cfo_targets[i] * n;
                    i_val = $rtoi(10000.0 * $cos(phase));
                    q_val = $rtoi(10000.0 * $sin(phase));
                    
                    item = coarse_cfo_core_seq_item::type_id::create("item");
                    start_item(item);
                    item.start = 1; item.s_valid = 1; item.i_sym = i_val[15:0]; item.q_sym = q_val[15:0]; item.force_en = 0; item.force_val = 0;
                    finish_item(item);
                end
                for (int k = 0; k < 20; k++) begin
                    item = coarse_cfo_core_seq_item::type_id::create("item");
                    start_item(item); item.start = 0; item.s_valid = 0; item.i_sym = 0; item.q_sym = 0; item.force_en = 0; item.force_val = 0; finish_item(item);
                end
            end

            // 1. Cover Q2 Quadrant (sign_x=1, sign_y=0) -> Negative I, Positive Q
            for (int n = 0; n < 32; n++) begin
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item);
                item.start = (n == 0); item.s_valid = 1; item.i_sym = -10000; item.q_sym = 5000; item.force_en = 0; item.force_val = 0;
                finish_item(item);
            end
            for (int k = 0; k < 20; k++) begin
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item); item.start = 0; item.s_valid = 0; item.i_sym = 0; item.q_sym = 0; item.force_en = 0; item.force_val = 0; finish_item(item);
            end

            // 2. Cover Force Mode & >32 symbols condition (count_q < 32)_0
            for (int n = 0; n < 40; n++) begin // 40 > 32
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item);
                item.start = (n == 0); item.s_valid = 1; item.i_sym = 100; item.q_sym = 100; 
                item.force_en = 1; item.force_val = 24'hABCDEF; // Force CFO
                finish_item(item);
            end
            for (int k = 0; k < 20; k++) begin
                item = coarse_cfo_core_seq_item::type_id::create("item");
                start_item(item); item.start = 0; item.s_valid = 0; item.i_sym = 0; item.q_sym = 0; item.force_en = 0; item.force_val = 0; finish_item(item);
            end
        endtask
    endclass
endpackage