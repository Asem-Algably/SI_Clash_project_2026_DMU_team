package sync_system_top_env_pac;
    import uvm_pkg::*;
    import sync_system_top_agtt::*;
    import sync_system_top_coverage_pkg::*;
    import sync_system_top_scoreborad_pck::*;
    `include "uvm_macros.svh"

    class sync_system_top_env extends uvm_env;
        `uvm_component_utils(sync_system_top_env)

        sync_system_top_agt        agt;
        sync_system_top_scoreborad sb;
        sync_system_top_cover      cov;

        function new(string name = "sync_system_top_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = sync_system_top_agt::type_id::create("agt", this);
            sb  = sync_system_top_scoreborad::type_id::create("sb", this);
            cov = sync_system_top_cover::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.agt_ap.connect(sb.sb_export);      // actual outputs         -> scoreboard
            agt.exp_ap.connect(sb.exp_export);     // golden output symbols  -> scoreboard
            agt.st_ap.connect(sb.st_export);       // golden FSM states      -> scoreboard
            agt.agt_ap.connect(cov.cov_export);    // actual outputs         -> coverage
        endfunction
    endclass
endpackage
