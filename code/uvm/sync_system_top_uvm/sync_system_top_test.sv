package sync_system_top_test_pkg;
    import uvm_pkg::*;
    import sync_system_top_env_pac::*;
    import sync_system_top_configuration::*;
    import reset_sequence::*;
    import golden_sequence::*;
    import main_sequence::*;
    `include "uvm_macros.svh"

    // Run options (plusargs):
    //   +SEQ=main            directed smoke test (DFT sweep + force overrides), no golden checking
    //   +MOD_TYPE=<0|1>      modulation driven with the golden vectors (default 1 = 16-QAM)
    //   +EXP_CFO=<int>       expected coarse CFO (default 1089400 from expected_metrics.txt)
    //   +NO_CFO_CHECK        disable the coarse CFO check
    //   +CHECK_LOCK          make lock_detect vs golden an error (default: informational)
    //   +VEC_FILE=<path>     vector file (default tb_top_vec.hex in the sim directory)
    class sync_system_top_test extends uvm_test;
        `uvm_component_utils(sync_system_top_test)

        sync_system_top_confg conf_sync_system_top;
        sync_system_top_env   env_sync_system_top;
        reset_seq             reset_seqq;
        golden_seq            golden_seqq;
        sync_main_seq         main_seqq;

        function new(string name = "sync_system_top_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            conf_sync_system_top = sync_system_top_confg::type_id::create("cfg");
            if (!uvm_config_db#(virtual sync_system_top_inter)::get(this, "", "sync_system_top_test_vif", conf_sync_system_top.sync_system_top_test_vif))
                `uvm_fatal("TEST_BUILD", "virtual interface not set in config_db")
            conf_sync_system_top.is_active = UVM_ACTIVE;
            uvm_config_db#(sync_system_top_confg)::set(this, "env*", "CFG", conf_sync_system_top);

            env_sync_system_top = sync_system_top_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            virtual sync_system_top_inter vif;
            string                        seq_sel;
            int                           cfo_arg;

            super.run_phase(phase);
            vif = conf_sync_system_top.sync_system_top_test_vif;

            phase.raise_objection(this);

            if ($value$plusargs("EXP_CFO=%d", cfo_arg)) env_sync_system_top.sb.exp_coarse_cfo = cfo_arg;
            if ($test$plusargs("NO_CFO_CHECK"))         env_sync_system_top.sb.check_cfo      = 1'b0;
            if ($test$plusargs("CHECK_LOCK"))           env_sync_system_top.sb.check_lock     = 1'b1;

            // 1) reset
            reset_seqq = reset_seq::type_id::create("reset_seq");
            reset_seqq.start(env_sync_system_top.agt.sqr);
            repeat (2) @(posedge vif.clk);

            // 2) stimulus: golden vectors (default) or directed smoke test (+SEQ=main)
            if ($value$plusargs("SEQ=%s", seq_sel) && (seq_sel == "main")) begin
                `uvm_info("TEST", "Running directed main_seq (golden checking disabled)", UVM_LOW)
                env_sync_system_top.sb.enable_check = 1'b0;
                main_seqq = sync_main_seq::type_id::create("main_seq");
                main_seqq.start(env_sync_system_top.agt.sqr);
            end else begin
                golden_seqq = golden_seq::type_id::create("golden_seq");
                golden_seqq.start(env_sync_system_top.agt.sqr);
            end

            // 3) drain: let the last outputs come out of the DUT pipeline
            repeat (40) @(posedge vif.clk);

            `uvm_info("TEST", $sformatf("correct_count=%0d, wrong_count=%0d",
                      env_sync_system_top.sb.correct_count, env_sync_system_top.sb.wrong_count), UVM_LOW)

            phase.drop_objection(this);
        endtask
    endclass
endpackage
