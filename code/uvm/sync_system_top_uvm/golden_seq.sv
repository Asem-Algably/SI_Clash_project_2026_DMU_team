package golden_sequence;
    import uvm_pkg::*;
    import sync_system_top_sequence_item::*;
    `include "uvm_macros.svh"

    // Replays tb_top_vec.hex. One line = one clock cycle:
    //   valid_i_q_sob_expvalid_expI_expQ_state_explock
    //   1_fe4_2a8_1_0_0000_0000_1_0   (19 hex digits once '_' are removed)
    class golden_seq extends uvm_sequence#(sync_system_top_seq_item);
        `uvm_object_utils(golden_seq)

        int unsigned num_tail_idle = 10;
        logic [1:0]  mod_type      = 2'b01;   // expected_metrics.txt: mod_type = 1 (16-QAM)
        int          num_vecs      = 0;
        int          num_exp_syms  = 0;

        function new(string name = "golden_seq");
            super.new(name);
        endfunction

        // Keep only the hex digits of a line ('_', spaces, CR/LF are dropped)
        function string hex_only(string s);
            string r;
            byte   c;
            r = "";
            for (int k = 0; k < s.len(); k++) begin
                c = s.getc(k);
                if ((c >= "0" && c <= "9") || (c >= "a" && c <= "f") || (c >= "A" && c <= "F"))
                    r = {r, s.substr(k, k)};
            end
            return r;
        endfunction

        task body();
            int                      fd;
            string                   line, hexs, fname;
            string                   candidates[$];
            int                      mt;
            sync_system_top_seq_item item;

            if ($value$plusargs("MOD_TYPE=%d", mt)) mod_type = mt[1:0];

            // -------- locate and open the vector file --------
            if ($value$plusargs("VEC_FILE=%s", fname))
                candidates.push_back(fname);
            candidates.push_back("tb_top_vec.hex");
            candidates.push_back("../vectors/tb_top_vec.hex");

            fd = 0;
            foreach (candidates[k]) begin
                if (fd == 0) begin
                    fd = $fopen(candidates[k], "r");
                    if (fd != 0) fname = candidates[k];
                end
            end
            if (fd == 0)
                `uvm_fatal("GOLDEN_SEQ", "Could not open tb_top_vec.hex - put it in the simulation directory or pass +VEC_FILE=<path>")

            // -------- one item per vector line --------
            while (!$feof(fd)) begin
                line = "";
                if ($fgets(line, fd) == 0) break;
                hexs = hex_only(line);
                if (hexs.len() != 19) continue;          // blank / malformed line

                item = sync_system_top_seq_item::type_id::create("item");
                start_item(item);

                item.rst_n     = 1'b1;
                item.golden    = 1'b1;
                item.mod_type  = mod_type;
                item.valid     = hexs.substr(0, 0).atohex();
                item.i_in      = hexs.substr(1, 3).atohex();
                item.q_in      = hexs.substr(4, 6).atohex();
                item.start     = hexs.substr(7, 7).atohex();
                item.exp_valid = hexs.substr(8, 8).atohex();
                item.exp_i     = hexs.substr(9, 12).atohex();
                item.exp_q     = hexs.substr(13, 16).atohex();
                item.exp_state = hexs.substr(17, 17).atohex();
                item.exp_lock  = hexs.substr(18, 18).atohex();

                finish_item(item);

                num_vecs++;
                if (item.exp_valid) num_exp_syms++;
            end
            $fclose(fd);

            `uvm_info("GOLDEN_SEQ", $sformatf("Loaded %0d vectors (%0d expected output symbols) from %s",
                      num_vecs, num_exp_syms, fname), UVM_LOW)

            if (num_vecs == 0)
                `uvm_fatal("GOLDEN_SEQ", "Vector file was opened but no valid lines were parsed")

            // Idle at the end so the inputs do not keep the last vector
            repeat (num_tail_idle) begin
                item = sync_system_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b1;
                item.valid = 1'b0;
                item.start = 1'b0;
                item.i_in  = 12'sd0;
                item.q_in  = 12'sd0;
                finish_item(item);
            end
        endtask
    endclass
endpackage
