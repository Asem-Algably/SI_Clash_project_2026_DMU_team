package derotator_configuration;
import uvm_pkg::*;
`include "uvm_macros.svh"
class derotator_confg extends uvm_object;
    `uvm_object_utils(derotator_confg)
        virtual derotator_inter derotator_test_vif;
        uvm_active_passive_enum is_active;
        function new(string name = "derotator_confg" );
        super.new(name);
        endfunction
endclass //className extends superClass
endpackage
