package str_top_configuration;
import uvm_pkg::*;
`include "uvm_macros.svh"
class str_top_confg extends uvm_object;
    `uvm_object_utils(str_top_confg)
        virtual str_top_inter str_top_test_vif;
        uvm_active_passive_enum is_active;
        function new(string name = "str_top_confg" );
        super.new(name);
        endfunction
endclass //className extends superClass
endpackage
