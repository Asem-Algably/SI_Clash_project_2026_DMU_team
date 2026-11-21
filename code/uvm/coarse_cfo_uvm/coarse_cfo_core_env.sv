package coarse_cfo_core_env_pac;
import uvm_pkg::*;
import coarse_cfo_core_agtt::*;
import coarse_cfo_core_coverage_pkg::*;
import coarse_cfo_core_scoreborad_pck::*;
`include "uvm_macros.svh"

class coarse_cfo_core_env extends uvm_env;
    `uvm_component_utils(coarse_cfo_core_env)
    coarse_cfo_core_agt agt;
    coarse_cfo_core_scoreborad sb;
    coarse_cfo_core_cover cov;
    function new(string name = "coarse_cfo_core_env" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        agt = coarse_cfo_core_agt::type_id::create("agt",this);
        sb = coarse_cfo_core_scoreborad::type_id::create("sb",this);
        cov = coarse_cfo_core_cover::type_id::create("cov",this);
    endfunction
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        agt.agt_ap.connect(sb.sb_export);
        agt.agt_ap.connect(cov.cov_export);
    endfunction
endclass

endpackage
