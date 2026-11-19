import costas_top_test_pkg::*;
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
    costas_top_inter costas_top_test_vif(clk);
    costas_top dut (/*put your variables*/);
    bind costas_top sva sva_inst(/*put your variables*/);
    initial begin
    uvm_config_db#(virtual costas_top_inter)::set(null,"*","costas_top_test_vif",costas_top_test_vif);
    run_test("costas_top_test");
    end

endmodule
