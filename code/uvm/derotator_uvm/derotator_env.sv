package derotator_env_pac;
import uvm_pkg::*;
import derotator_agtt::*;
import derotator_coverage_pkg::*;
import derotator_scoreborad_pck::*;
`include "uvm_macros.svh"

class derotator_env extends uvm_env;
    `uvm_component_utils(derotator_env)
    derotator_agt agt;
    derotator_scoreborad sb;
    derotator_cover cov;
    function new(string name = "derotator_env" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        agt = derotator_agt::type_id::create("agt",this);
        sb = derotator_scoreborad::type_id::create("sb",this);
        cov = derotator_cover::type_id::create("cov",this);
    endfunction
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        agt.agt_ap.connect(sb.sb_export);
        agt.agt_ap.connect(cov.cov_export);
    endfunction
endclass

endpackage
