package costas_top_env_pac;
import uvm_pkg::*;
import costas_top_agtt::*;
import costas_top_coverage_pkg::*;
import costas_top_scoreborad_pck::*;
`include "uvm_macros.svh"

class costas_top_env extends uvm_env;
    `uvm_component_utils(costas_top_env)
    costas_top_agt agt;
    costas_top_scoreborad sb;
    costas_top_cover cov;
    function new(string name = "costas_top_env" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        agt = costas_top_agt::type_id::create("agt",this);
        sb = costas_top_scoreborad::type_id::create("sb",this);
        cov = costas_top_cover::type_id::create("cov",this);
    endfunction
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        agt.agt_ap.connect(sb.sb_export);
        agt.exp_ap.connect(sb.exp_export);
        agt.agt_ap.connect(cov.cov_export);
    endfunction
endclass

endpackage
