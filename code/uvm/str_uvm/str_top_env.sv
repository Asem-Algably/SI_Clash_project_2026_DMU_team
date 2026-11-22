package str_top_env_pac;
    import uvm_pkg::*;
    import str_top_agtt::*;
    import str_top_coverage_pkg::*;
    import str_top_scoreborad_pck::*;
    `include "uvm_macros.svh"

    class str_top_env extends uvm_env;
        `uvm_component_utils(str_top_env)

        str_top_agt        agt;
        str_top_scoreborad sb;
        str_top_cover      cov;

        function new(string name = "str_top_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = str_top_agt::type_id::create("agt", this);
            sb  = str_top_scoreborad::type_id::create("sb", this);
            cov = str_top_cover::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.agt_ap.connect(sb.sb_export);      // actual outputs  -> scoreboard
            agt.exp_ap.connect(sb.exp_export);     // golden symbols  -> scoreboard
            agt.agt_ap.connect(cov.cov_export);    // actual outputs  -> coverage
        endfunction
    endclass
endpackage
