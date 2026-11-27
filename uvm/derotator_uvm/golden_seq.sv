package derotator_golden_seq_pkg;
    import uvm_pkg::*;
    import derotator_sequence_item::*;
    `include "uvm_macros.svh"

    class derotator_golden_seq extends uvm_sequence#(derotator_seq_item);
        `uvm_object_utils(derotator_golden_seq)

        int num_vecs     = 0;
        int num_exp_syms = 0;

        function new(string name = "derotator_golden_seq");
            super.new(name);
        endfunction

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

        task drive_harness_reset();
            derotator_seq_item item;
            repeat (3) begin
                item = derotator_seq_item::type_id::create("item");
                start_item(item);
                item.rst_ni = 1'b0;
                item.s_axis_valid_i = 1'b0; item.coarse_valid_i = 1'b0;
                item.freq_adj_valid_i = 1'b0; item.phase_adj_valid_i = 1'b0;
                item.force_freq_en_i = 1'b0; item.exp_valid = 1'b0;
                finish_item(item);
            end
            repeat (2) begin
                item = derotator_seq_item::type_id::create("item");
                start_item(item);
                item.rst_ni = 1'b1;
                item.s_axis_valid_i = 1'b0; item.coarse_valid_i = 1'b0;
                item.freq_adj_valid_i = 1'b0; item.phase_adj_valid_i = 1'b0;
                item.force_freq_en_i = 1'b0; item.exp_valid = 1'b0;
                finish_item(item);
            end
        endtask

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
            int                fd, cidx;
            string             line, hexs, fname;
            string             case_files[$];
            string             candidates[$];
            derotator_seq_item item;

            load_case_list(case_files);
            if (case_files.size() == 0) begin
                candidates.push_back("tb_derot_vec.hex");
                candidates.push_back("../vectors/tb_derot_vec.hex");
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
                `uvm_fatal("GOLDEN_SEQ", "No derotator vector files found (neither cases/cases_list.txt nor tb_derot_vec.hex)")

            foreach (case_files[cidx]) begin
                int case_vecs = 0;
                drive_harness_reset();
                fname = case_files[cidx];
                fd = $fopen(fname, "r");
                if (fd == 0)
                    `uvm_fatal("GOLDEN_SEQ", $sformatf("Could not open derotator case file: %s", fname))

                while (!$feof(fd)) begin
                    line = "";
                    if ($fgets(line, fd) == 0) break;
                    if (is_comment_or_blank(line)) continue;
                    hexs = hex_only(line);
                    if (hexs.len() != 43 && hexs.len() != 53) continue;

                    item = derotator_seq_item::type_id::create("item");
                    start_item(item);

                    if (hexs.len() == 53) begin
                        item.rst_ni            = hexs.substr(0, 0).atohex();
                        item.s_axis_valid_i    = hexs.substr(1, 1).atohex();
                        item.s_axis_i_sym_i    = hexs.substr(2, 5).atohex();
                        item.s_axis_q_sym_i    = hexs.substr(6, 9).atohex();
                        item.coarse_valid_i    = hexs.substr(10, 10).atohex();
                        item.coarse_word_i     = hexs.substr(11, 16).atohex();
                        item.freq_adj_valid_i  = hexs.substr(17, 17).atohex();
                        item.freq_adj_i        = hexs.substr(18, 25).atohex();
                        item.force_freq_en_i   = hexs.substr(26, 26).atohex();
                        item.force_freq_i      = hexs.substr(27, 34).atohex();
                        item.phase_adj_valid_i = hexs.substr(35, 35).atohex();
                        item.phase_adj_i       = hexs.substr(36, 43).atohex();
                        item.exp_valid         = hexs.substr(44, 44).atohex();
                        item.exp_i             = hexs.substr(45, 48).atohex();
                        item.exp_q             = hexs.substr(49, 52).atohex();
                    end else begin
                        // Legacy 43-hex-char export_block_test_vectors format
                        item.rst_ni            = 1'b1;
                        item.s_axis_valid_i    = hexs.substr(0, 0).atohex();
                        item.s_axis_i_sym_i    = hexs.substr(1, 4).atohex();
                        item.s_axis_q_sym_i    = hexs.substr(5, 8).atohex();
                        item.coarse_valid_i    = hexs.substr(9, 9).atohex();
                        item.coarse_word_i     = hexs.substr(10, 15).atohex();
                        item.freq_adj_valid_i  = hexs.substr(16, 16).atohex();
                        item.freq_adj_i        = hexs.substr(17, 24).atohex();
                        item.force_freq_en_i   = 1'b0;
                        item.force_freq_i      = 32'd0;
                        item.phase_adj_valid_i = hexs.substr(25, 25).atohex();
                        item.phase_adj_i       = hexs.substr(26, 33).atohex();
                        item.exp_valid         = hexs.substr(34, 34).atohex();
                        item.exp_i             = hexs.substr(35, 38).atohex();
                        item.exp_q             = hexs.substr(39, 42).atohex();
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

            repeat (10) begin
                item = derotator_seq_item::type_id::create("item");
                start_item(item);
                item.rst_ni = 1'b1;
                item.s_axis_valid_i = 1'b0; item.exp_valid = 1'b0;
                finish_item(item);
            end
        endtask
    endclass
endpackage