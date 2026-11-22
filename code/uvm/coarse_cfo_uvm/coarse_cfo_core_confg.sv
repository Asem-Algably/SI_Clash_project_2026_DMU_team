package coarse_cfo_core_configuration;
import uvm_pkg::*;
`include "uvm_macros.svh"
class coarse_cfo_core_confg extends uvm_object;
    `uvm_object_utils(coarse_cfo_core_confg)
        virtual coarse_cfo_core_inter coarse_cfo_core_test_vif;
        uvm_active_passive_enum is_active;
        function new(string name = "coarse_cfo_core_confg" );
        super.new(name);
        endfunction
endclass //className extends superClass
endpackage
