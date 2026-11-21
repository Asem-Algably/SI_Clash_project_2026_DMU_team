package costas_top_configuration;
import uvm_pkg::*;
`include "uvm_macros.svh"
class costas_top_confg extends uvm_object;
    `uvm_object_utils(costas_top_confg)
        virtual costas_top_inter costas_top_test_vif;
        uvm_active_passive_enum is_active;
        function new(string name = "costas_top_confg" );
        super.new(name);
        endfunction
endclass //className extends superClass
endpackage
