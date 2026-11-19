package sync_system_top_test_pkg;
import sync_system_top_env_pac::*;
import uvm_pkg::*;
import sync_system_top_configuration::*;
import reset_sequence::*;
// import your own sequences here
`include "uvm_macros.svh"
class sync_system_top_test extends uvm_test;
    `uvm_component_utils(sync_system_top_test)
    sync_system_top_confg conf_sync_system_top;
    sync_system_top_env env_sync_system_top;
    reset_seq reset_seqq;
    // declare your own sequence handles here
    function new(string name = "sync_system_top_test",uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        env_sync_system_top = sync_system_top_env::type_id::create("env",this);
        conf_sync_system_top = sync_system_top_confg::type_id::create("cfg",this);
        reset_seqq = reset_seq::type_id::create("reset_seq",this);
        if(!uvm_config_db#(virtual sync_system_top_inter)::get(this,"","sync_system_top_test_vif",conf_sync_system_top.sync_system_top_test_vif))
        `uvm_fatal("build_phase","virtual interface not set in config_db");
        conf_sync_system_top.is_active = UVM_ACTIVE;
        uvm_config_db#(sync_system_top_confg)::set(null,"*","CFG",conf_sync_system_top);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        // run sequences
        reset_seqq.start(env_sync_system_top.agt.sqr);

        `uvm_info("run_phase", $sformatf("correct_count=%0d , wrong_count = %0d",env_sync_system_top.sb.correct_count,env_sync_system_top.sb.wrong_count),UVM_MEDIUM)

        phase.drop_objection(this);
    endtask


endclass

endpackage
