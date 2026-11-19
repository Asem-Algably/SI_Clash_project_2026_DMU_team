package sync_system_top_configuration;
import uvm_pkg::*;
`include "uvm_macros.svh"
class sync_system_top_confg extends uvm_object;
    `uvm_object_utils(sync_system_top_confg)
        virtual sync_system_top_inter sync_system_top_test_vif;
        uvm_active_passive_enum is_active;
        function new(string name = "sync_system_top_confg" );
        super.new(name);
        endfunction
endclass //className extends superClass
endpackage
