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

        function bit is_comment_or_blank(string s);
            for (int k = 0; k < s.len(); k++) begin
                byte c = s.getc(k);
                if (c == " " || c == "\t" || c == 8'h0d || c == "\n") continue;
                return (c == "#" || c == "/");
            end
            return 1'b1;
        endfunction

        task load_case_list(output string files[$]);
            int fd;
            string line, cleaned, arg;
            files.delete();
            if ($value$plusargs("VEC_FILE=%s", arg)) begin
                files.push_back(arg);
                return;
            end
            fd = $fopen("cases/cases_list.txt", "r");
            if (fd != 0) begin
                while (!$feof(fd)) begin
                    line = "";
                    if ($fgets(line, fd) == 0) break;
                    if (is_comment_or_blank(line)) continue;
                    cleaned = "";
                    for (int k = 0; k < line.len(); k++) begin
                        byte c = line.getc(k);
                        if (c != " " && c != "\t" && c != 8'h0d && c != "\n")
                            cleaned = {cleaned, line.substr(k, k)};
                    end
                    if (cleaned.len() > 0) files.push_back(cleaned);
                end
                $fclose(fd);
            end
        endtask

        task body();
            int                      fd;
            string                   line, hexs, fname;
            string                   case_files[$];
            string                   candidates[$];
            int                      mt, cidx;
            sync_system_top_seq_item item;

            if ($value$plusargs("MOD_TYPE=%d", mt)) mod_type = mt[1:0];

            load_case_list(case_files);
            if (case_files.size() == 0) begin
                candidates.push_back("tb_top_vec.hex");
                candidates.push_back("../vectors/tb_top_vec.hex");
                candidates.push_back("tb/vectors/tb_top_vec.hex");
                candidates.push_back("uvm/vectors/tb_top_vec.hex");
                foreach (candidates[k]) begin
                    fd = $fopen(candidates[k], "r");
                    if (fd != 0) begin
                        $fclose(fd);
                        case_files.push_back(candidates[k]);
                        break;
                    end
                end
            end
            if (case_files.size() == 0)
                `uvm_fatal("GOLDEN_SEQ", "No vector files found (neither cases/cases_list.txt nor tb_top_vec.hex)")

            foreach (case_files[cidx]) begin
                int case_vecs = 0;
                fname = case_files[cidx];
                fd = $fopen(fname, "r");
                if (fd == 0)
                    `uvm_fatal("GOLDEN_SEQ", $sformatf("Could not open case vector file: %s", fname))

                while (!$feof(fd)) begin
                    line = "";
                    if ($fgets(line, fd) == 0) break;
                    if (is_comment_or_blank(line)) continue;
                    hexs = hex_only(line);
                    if (hexs.len() != 19 && hexs.len() != 49) continue;

                    item = sync_system_top_seq_item::type_id::create("item");
                    start_item(item);

                    item.golden = 1'b1;
                    if (hexs.len() == 49) begin
                        item.rst_n         = hexs.substr(0, 0).atohex();
                        item.valid         = hexs.substr(1, 1).atohex();
                        item.i_in          = hexs.substr(2, 4).atohex();
                        item.q_in          = hexs.substr(5, 7).atohex();
                        item.start         = hexs.substr(8, 8).atohex();
                        item.mod_type      = hexs.substr(9, 9).atohex();
                        item.dft_sel       = hexs.substr(10, 10).atohex();
                        item.force_w_en    = hexs.substr(11, 11).atohex();
                        item.force_w       = hexs.substr(12, 15).atohex();
                        item.force_cfo_en  = hexs.substr(16, 16).atohex();
                        item.force_cfo     = hexs.substr(17, 22).atohex();
                        item.force_freq_en = hexs.substr(23, 23).atohex();
                        item.force_freq    = hexs.substr(24, 31).atohex();
                        item.exp_valid     = hexs.substr(32, 32).atohex();
                        item.exp_i         = hexs.substr(33, 36).atohex();
                        item.exp_q         = hexs.substr(37, 40).atohex();
                        item.exp_state     = hexs.substr(41, 41).atohex();
                        item.exp_lock      = hexs.substr(42, 42).atohex();
                        item.has_exp_cfo   = 1'b1;
                        item.exp_cfo       = hexs.substr(43, 48).atohex();
                    end else begin
                        item.rst_n         = 1'b1;
                        item.mod_type      = mod_type;
                        item.valid         = hexs.substr(0, 0).atohex();
                        item.i_in          = hexs.substr(1, 3).atohex();
                        item.q_in          = hexs.substr(4, 6).atohex();
                        item.start         = hexs.substr(7, 7).atohex();
                        item.exp_valid     = hexs.substr(8, 8).atohex();
                        item.exp_i         = hexs.substr(9, 12).atohex();
                        item.exp_q         = hexs.substr(13, 16).atohex();
                        item.exp_state     = hexs.substr(17, 17).atohex();
                        item.exp_lock      = hexs.substr(18, 18).atohex();
                        item.has_exp_cfo   = 1'b0;
                    end

                    finish_item(item);
                    case_vecs++;
                    num_vecs++;
                    if (item.exp_valid) num_exp_syms++;
                end
                $fclose(fd);
                `uvm_info("GOLDEN_SEQ", $sformatf("Loaded %0d vectors from %s (total=%0d, exp_syms=%0d)",
                          case_vecs, fname, num_vecs, num_exp_syms), UVM_LOW)
            end

            if (num_vecs == 0)
                `uvm_fatal("GOLDEN_SEQ", "Vector file(s) opened but no valid lines were parsed")

            // Idle at the end so the inputs do not keep the last vector
            repeat (num_tail_idle) begin
                item = sync_system_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n         = 1'b1;
                item.valid         = 1'b0;
                item.start         = 1'b0;
                item.i_in          = 12'sd0;
                item.q_in          = 12'sd0;
                item.dft_sel       = 4'd0;
                item.force_w_en    = 1'b0;
                item.force_cfo_en  = 1'b0;
                item.force_freq_en = 1'b0;
                finish_item(item);
            end
        endtask
    endclass
endpackage
