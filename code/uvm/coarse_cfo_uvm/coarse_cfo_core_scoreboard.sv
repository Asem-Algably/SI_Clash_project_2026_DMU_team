package coarse_cfo_core_scoreborad_pck;
    import uvm_pkg::*;
    import coarse_cfo_core_sequence_item::*;
    `include "uvm_macros.svh"

    class coarse_cfo_core_scoreborad extends uvm_scoreboard;
        `uvm_component_utils(coarse_cfo_core_scoreborad)

        uvm_analysis_export #(coarse_cfo_core_seq_item) sb_export;
        uvm_tlm_analysis_fifo #(coarse_cfo_core_seq_item) sb_fifo;
        
        int correct_count = 0;
        int wrong_count   = 0;
        
        int expected_cfo  = 1089400; 
        int tolerance     = 5000; 
        
        // متغير جديد عشان نشغل ونقفل الفحص
        bit check_enable  = 1; 

        function new(string name = "coarse_cfo_core_scoreborad", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sb_export = new("sb_export", this);
            sb_fifo   = new("sb_fifo", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
        endfunction

        task run_phase(uvm_phase phase);
            coarse_cfo_core_seq_item item;
            forever begin
                sb_fifo.get(item);
                // لو الـ check_enable شغال والـ valid عالي، قارن
                if (item.o_valid && check_enable) begin
                    if ((item.cfo >= (expected_cfo - tolerance)) && (item.cfo <= (expected_cfo + tolerance))) begin
                        correct_count++;
                        `uvm_info("SB", $sformatf("MATCH: cfo=%0d (Hex: %h) expected=%0d", item.cfo, item.cfo, expected_cfo), UVM_LOW)
                    end else begin
                        wrong_count++;
                        `uvm_error("SB", $sformatf("MISMATCH: got=%0d (Hex: %h), exp=%0d", item.cfo, item.cfo, expected_cfo))
                    end
                end
            end
        endtask
    endclass
endpackage