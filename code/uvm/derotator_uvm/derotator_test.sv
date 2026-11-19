package derotator_test_pkg;
import derotator_env_pac::*;
import uvm_pkg::*;
import derotator_configuration::*;
import reset_sequence::*;
// import your own sequences here
`include "uvm_macros.svh"
class derotator_test extends uvm_test;
    `uvm_component_utils(derotator_test)
    derotator_confg conf_derotator;
    derotator_env env_derotator;
    reset_seq reset_seqq;
    // declare your own sequence handles here
    function new(string name = "derotator_test",uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        env_derotator = derotator_env::type_id::create("env",this);
        conf_derotator = derotator_confg::type_id::create("cfg",this);
        reset_seqq = reset_seq::type_id::create("reset_seq",this);
        if(!uvm_config_db#(virtual derotator_inter)::get(this,"","derotator_test_vif",conf_derotator.derotator_test_vif))
        `uvm_fatal("build_phase","virtual interface not set in config_db");
        conf_derotator.is_active = UVM_ACTIVE;
        uvm_config_db#(derotator_confg)::set(null,"*","CFG",conf_derotator);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        // run sequences
        reset_seqq.start(env_derotator.agt.sqr);

        `uvm_info("run_phase", $sformatf("correct_count=%0d , wrong_count = %0d",env_derotator.sb.correct_count,env_derotator.sb.wrong_count),UVM_MEDIUM)

        phase.drop_objection(this);
    endtask


endclass

endpackage
