import derotator_test_pkg::*;
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
    derotator_inter derotator_test_vif(clk);
    derotator dut (/*put your variables*/);
    bind derotator sva sva_inst(/*put your variables*/);
    initial begin
    uvm_config_db#(virtual derotator_inter)::set(null,"*","derotator_test_vif",derotator_test_vif);
    run_test("derotator_test");
    end

endmodule
