package str_top_test_pkg;
    import uvm_pkg::*;
    import str_top_env_pac::*;
    import str_top_configuration::*;
    import reset_sequence::*;
    import golden_sequence::*;
    import main_sequence::*;
    `include "uvm_macros.svh"

    class str_top_test extends uvm_test;
        `uvm_component_utils(str_top_test)

        str_top_confg conf_str_top;
        str_top_env   env_str_top;
        reset_seq     reset_seqq;
        golden_seq    golden_seqq;
        str_main_seq  main_seqq;

        function new(string name = "str_top_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            // Configuration object (virtual interface + active/passive)
            conf_str_top = str_top_confg::type_id::create("cfg");
            if (!uvm_config_db#(virtual str_top_inter)::get(this, "", "str_top_test_vif", conf_str_top.str_top_test_vif))
                `uvm_fatal("TEST_BUILD", "virtual interface not set in config_db")
            conf_str_top.is_active = UVM_ACTIVE;
            uvm_config_db#(str_top_confg)::set(this, "env*", "CFG", conf_str_top);

            env_str_top = str_top_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            virtual str_top_inter vif;
            string                seq_sel;

            super.run_phase(phase);
            vif = conf_str_top.str_top_test_vif;

            phase.raise_objection(this);

            // 1) reset
            reset_seqq = reset_seq::type_id::create("reset_seq");
            reset_seqq.start(env_str_top.agt.sqr);
            repeat (2) @(posedge vif.clk);

            // 2) stimulus: golden vectors (default) or directed smoke test (+SEQ=main)
            if ($value$plusargs("SEQ=%s", seq_sel) && (seq_sel == "main")) begin
                `uvm_info("TEST", "Running directed main_seq (golden checking disabled)", UVM_LOW)
                env_str_top.sb.enable_check = 1'b0;
                main_seqq = str_main_seq::type_id::create("main_seq");
                main_seqq.start(env_str_top.agt.sqr);
            end else begin
                golden_seqq = golden_seq::type_id::create("golden_seq");
                golden_seqq.start(env_str_top.agt.sqr);
            end

            // 3) drain: let the last outputs come out of the DUT pipeline
            repeat (20) @(posedge vif.clk);

            `uvm_info("TEST", $sformatf("correct_count=%0d, wrong_count=%0d",
                      env_str_top.sb.correct_count, env_str_top.sb.wrong_count), UVM_LOW)

            phase.drop_objection(this);
        endtask
    endclass
endpackage
