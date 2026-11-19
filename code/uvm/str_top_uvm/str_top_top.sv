import str_top_test_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"
module top ();
    bit clk ;
    initial begin
        forever begin
            #10;
            clk=!clk;
        end
    end
    str_top_inter str_top_test_vif(clk);
    str_top dut (/*put your variables*/);
    bind str_top sva sva_inst(/*put your variables*/);
    initial begin
    uvm_config_db#(virtual str_top_inter)::set(null,"*","str_top_test_vif",str_top_test_vif);
    run_test("str_top_test");
    end

endmodule
