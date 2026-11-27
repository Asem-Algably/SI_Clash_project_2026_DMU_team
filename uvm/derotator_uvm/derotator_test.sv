package derotator_test_pkg;
    import uvm_pkg::*;
    import derotator_env_pac::*;
    import derotator_configuration::*;
    import derotator_golden_seq_pkg::*; 
    `include "uvm_macros.svh"

    class derotator_test extends uvm_test;
        `uvm_component_utils(derotator_test)
        
        derotator_confg conf_derotator;
        derotator_env   env_derotator;
        derotator_golden_seq golden_seq;
        
        function new(string name = "derotator_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase (uvm_phase phase);
            super.build_phase(phase);
            
            env_derotator = derotator_env::type_id::create("env", this);
            conf_derotator = derotator_confg::type_id::create("cfg", this);
            
            if(!uvm_config_db#(virtual derotator_inter)::get(this, "", "derotator_test_vif", conf_derotator.derotator_test_vif))
                `uvm_fatal("build_phase", "Virtual interface not set in config_db")
                
            conf_derotator.is_active = UVM_ACTIVE;
            uvm_config_db#(derotator_confg)::set(null, "*", "CFG", conf_derotator);
        endfunction

        task run_phase (uvm_phase phase);
            super.run_phase(phase);
            
            phase.raise_objection(this);
            
            `uvm_info("TEST", "Starting Golden Sequence from tb_derot_vec.hex ...", UVM_LOW)
            
            golden_seq = derotator_golden_seq::type_id::create("golden_seq");
            golden_seq.start(env_derotator.agt.sqr);

            // Wait to flush the pipeline
            repeat(10) @(posedge conf_derotator.derotator_test_vif.clk);

            `uvm_info("TEST", $sformatf("TEST FINISHED. Correct Count = %0d, Wrong Count = %0d", 
                      env_derotator.sb.correct_count, env_derotator.sb.wrong_count), UVM_LOW)
            
            if (env_derotator.sb.wrong_count == 0 &&
                env_derotator.sb.extra_count == 0 &&
                env_derotator.sb.expected_queue.size() == 0 &&
                env_derotator.sb.correct_count > 0) begin
                `uvm_info("TEST", "*** SUCCESS: All vectors matched! ***", UVM_LOW)
            end else begin
                `uvm_error("TEST", "*** FAILURE: Vector mismatch or missing outputs! ***")
            end

            phase.drop_objection(this);
        endtask
    endclass
endpackage