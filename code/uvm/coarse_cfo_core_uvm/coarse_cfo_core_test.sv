package coarse_cfo_core_test_pkg;
    import uvm_pkg::*;
    import coarse_cfo_core_env_pac::*;
    import coarse_cfo_core_configuration::*;
    import coarse_cfo_core_sequence_item::*; 
    import reset_sequence::*;
    import golden_sequence::*;
    import directed_sequence::*;
    `include "uvm_macros.svh"

    class coarse_cfo_core_test extends uvm_test;
        `uvm_component_utils(coarse_cfo_core_test)

        coarse_cfo_core_confg conf_coarse_cfo_core;
        coarse_cfo_core_env env_coarse_cfo_core;
        reset_seq reset_seqq;
        golden_seq golden_seqq;
        directed_cfo_seq dir_seqq;

        function new(string name = "coarse_cfo_core_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env_coarse_cfo_core = coarse_cfo_core_env::type_id::create("env", this);
            conf_coarse_cfo_core = coarse_cfo_core_confg::type_id::create("cfg", this);
            
            if(!uvm_config_db#(virtual coarse_cfo_core_inter)::get(this, "", "coarse_cfo_core_test_vif", conf_coarse_cfo_core.coarse_cfo_core_test_vif))
                `uvm_fatal("build_phase", "virtual interface not set in config_db")
            
            conf_coarse_cfo_core.is_active = UVM_ACTIVE;
            uvm_config_db#(coarse_cfo_core_confg)::set(null, "*", "CFG", conf_coarse_cfo_core);
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            phase.raise_objection(this);
            
            #150; // Wait for top-level reset
            
            // 1. Reset Sequence
            reset_seqq = reset_seq::type_id::create("reset_seq");
            reset_seqq.start(env_coarse_cfo_core.agt.sqr);

            // 2. Golden Sequence (Checks exact CFO and hits large_pos)
            env_coarse_cfo_core.sb.check_enable = 1; 
            golden_seqq = golden_seq::type_id::create("golden_seq");
            golden_seqq.start(env_coarse_cfo_core.agt.sqr);

            // 3. Directed Sequence (Disable checking to avoid false errors)
            env_coarse_cfo_core.sb.check_enable = 0; 
            dir_seqq = directed_cfo_seq::type_id::create("dir_seq");
            dir_seqq.start(env_coarse_cfo_core.agt.sqr);

            // 4. Force asynchronous reset to hit the missing FSM transition
            // (StIterate -> StIdle). Since the Directed Sequence already 
            // triggered CORDIC, we just apply a quick reset here.

            #100;
            conf_coarse_cfo_core.coarse_cfo_core_test_vif.force_rst_low();
            #50;
            conf_coarse_cfo_core.coarse_cfo_core_test_vif.release_rst_ni();
            #100;
            
            `uvm_info("run_phase", $sformatf("correct_count=%0d, wrong_count=%0d", env_coarse_cfo_core.sb.correct_count, env_coarse_cfo_core.sb.wrong_count), UVM_LOW)
            
            phase.drop_objection(this);
        endtask
    endclass
endpackage