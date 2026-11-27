package golden_sequence;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class golden_seq extends uvm_sequence#(costas_top_seq_item);
        `uvm_object_utils(golden_seq)

        int num_vecs       = 0;
        int num_exp_pulses = 0;

        function new(string name = "golden_seq");
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
            costas_top_seq_item item;
            repeat (3) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b0; item.valid = 1'b0; item.mode = 2'b00;
                item.slicer_qpsk = 1'b1; item.preamble_end = 1'b0; item.mod_type = 2'b00;
                item.exp_fval = 1'b0; item.exp_pval = 1'b0;
                finish_item(item);
            end
            repeat (2) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b1; item.valid = 1'b0; item.mode = 2'b00;
                item.slicer_qpsk = 1'b1; item.preamble_end = 1'b0; item.mod_type = 2'b00;
                item.exp_fval = 1'b0; item.exp_pval = 1'b0;
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
            int                 fd, cidx;
            string              line, hexs, fname;
            string              case_files[$];
            string              candidates[$];
            costas_top_seq_item item;

            load_case_list(case_files);
            if (case_files.size() == 0) begin
                candidates.push_back("tb_costas_vec.hex");
                candidates.push_back("../vectors/tb_costas_vec.hex");
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
                `uvm_fatal("GOLDEN_SEQ", "No costas vector files found (neither cases/cases_list.txt nor tb_costas_vec.hex)")

            foreach (case_files[cidx]) begin
                int case_vecs = 0;
                if (cidx > 0) drive_harness_reset();
                fname = case_files[cidx];
                fd = $fopen(fname, "r");
                if (fd == 0)
                    `uvm_fatal("GOLDEN_SEQ", $sformatf("Could not open costas case file: %s", fname))

                while (!$feof(fd)) begin
                    line = "";
                    if ($fgets(line, fd) == 0) break;
                    if (is_comment_or_blank(line)) continue;
                    hexs = hex_only(line);
                    if (hexs.len() != 31 && hexs.len() != 33) continue;

                    item = costas_top_seq_item::type_id::create("item");
                    start_item(item);

                    item.costas_gain = 8'd0;
                    if (hexs.len() == 33) begin
                        item.rst_n         = hexs.substr(0, 0).atohex();
                        item.valid         = hexs.substr(1, 1).atohex();
                        item.i_sym         = hexs.substr(2, 5).atohex();
                        item.q_sym         = hexs.substr(6, 9).atohex();
                        item.mode          = hexs.substr(10, 10).atohex();
                        item.preamble_end  = hexs.substr(11, 11).atohex();
                        item.mod_type      = hexs.substr(12, 12).atohex();
                        item.slicer_qpsk   = hexs.substr(13, 13).atohex();
                        item.exp_fval      = hexs.substr(14, 14).atohex();
                        item.exp_freq_adj  = hexs.substr(15, 22).atohex();
                        item.exp_pval      = hexs.substr(23, 23).atohex();
                        item.exp_phase_adj = hexs.substr(24, 31).atohex();
                        item.exp_lock      = hexs.substr(32, 32).atohex();
                    end else begin
                        item.rst_n         = 1'b1;
                        item.valid         = hexs.substr(0, 0).atohex();
                        item.i_sym         = hexs.substr(1, 4).atohex();
                        item.q_sym         = hexs.substr(5, 8).atohex();
                        item.mode          = hexs.substr(9, 9).atohex();
                        item.preamble_end  = hexs.substr(10, 10).atohex();
                        item.mod_type      = hexs.substr(11, 11).atohex();
                        item.slicer_qpsk   = (item.mode != 2'b10);
                        item.exp_fval      = hexs.substr(12, 12).atohex();
                        item.exp_freq_adj  = hexs.substr(13, 20).atohex();
                        item.exp_pval      = hexs.substr(21, 21).atohex();
                        item.exp_phase_adj = hexs.substr(22, 29).atohex();
                        item.exp_lock      = hexs.substr(30, 30).atohex();
                    end

                    finish_item(item);
                    case_vecs++;
                    num_vecs++;
                    if (item.exp_fval || item.exp_pval) num_exp_pulses++;
                end
                $fclose(fd);
                `uvm_info("GOLDEN_SEQ", $sformatf("Loaded %0d vectors from %s (total=%0d, exp_pulses=%0d)",
                          case_vecs, fname, num_vecs, num_exp_pulses), UVM_LOW)
            end

            if (num_vecs == 0)
                `uvm_fatal("GOLDEN_SEQ", "Vector file(s) opened but no valid lines were parsed")

            repeat (20) begin
                item = costas_top_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b1; item.valid = 1'b0; item.mode = 2'b00;
                item.slicer_qpsk = 1'b1; item.preamble_end = 1'b0;
                item.exp_fval = 1'b0; item.exp_pval = 1'b0;
                finish_item(item);
            end
        endtask
    endclass
endpackage