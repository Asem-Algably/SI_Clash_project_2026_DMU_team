import sync_system_top_test_pkg::*;
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
    sync_system_top_inter sync_system_top_test_vif(clk);
    sync_system_top dut (/*put your variables*/);
    bind sync_system_top sva sva_inst(/*put your variables*/);
    initial begin
    uvm_config_db#(virtual sync_system_top_inter)::set(null,"*","sync_system_top_test_vif",sync_system_top_test_vif);
    run_test("sync_system_top_test");
    end

endmodule
