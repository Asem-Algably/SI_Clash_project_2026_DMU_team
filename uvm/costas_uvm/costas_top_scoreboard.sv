package costas_top_scoreborad_pck;
    import uvm_pkg::*;
    import costas_top_sequence_item::*;
    `include "uvm_macros.svh"

    class costas_top_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(costas_top_scoreborad)

        uvm_analysis_export #(costas_top_seq_item) sb_export;
        uvm_tlm_analysis_fifo #(costas_top_seq_item) sb_fifo;
        costas_top_seq_item item;

        int correct_count = 0;
        int wrong_count   = 0;
        int idx = 0;

        logic [123:0] vec_mem [0:20000];
        int num_vecs = 0;
        
        logic [3:0] v_exp_fval, v_exp_pval, v_exp_lock;
        logic signed [31:0] exp_freq_adj;
        logic [31:0] exp_phase_adj;
        logic exp_freq_valid, exp_phase_valid;

        function new(string name = "costas_top_scoreborad", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sb_export = new("sb_export", this);
            sb_fifo   = new("sb_fifo", this);
            
            // Just the filename since it's in the same folder
            $readmemh("tb_costas_vec.hex", vec_mem);
            while (vec_mem[num_vecs] !== 124'hx && num_vecs < 20000) begin
                num_vecs++;
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
        endfunction

        task run_phase(uvm_phase phase);
            int diff;
            forever begin
                sb_fifo.get(item);
                if (idx < num_vecs) begin
                    // Extract expected values from the vector
                    {v_exp_fval, exp_freq_adj, v_exp_pval, exp_phase_adj, v_exp_lock} = vec_mem[idx][67:0];
                    exp_freq_valid = v_exp_fval[0];
                    exp_phase_valid= v_exp_pval[0];

                    if (exp_freq_valid && item.freq_adj_valid) begin
                        diff = (item.freq_adj > exp_freq_adj) ? (item.freq_adj - exp_freq_adj) : (exp_freq_adj - item.freq_adj);
                        if (diff == 0) correct_count++;
                        else begin
                            wrong_count++;
                            `uvm_error("SB", $sformatf("FREQ MISMATCH: got=%0d, exp=%0d", item.freq_adj, exp_freq_adj))
                        end
                    end

                    if (exp_phase_valid && item.phase_adj_valid) begin
                        if (item.phase_adj == exp_phase_adj) correct_count++;
                        else begin
                            wrong_count++;
                            `uvm_error("SB", $sformatf("PHASE MISMATCH: got=%h, exp=%h", item.phase_adj, exp_phase_adj))
                        end
                    end
                    idx++;
                end
            end
        endtask
    endclass
endpackage