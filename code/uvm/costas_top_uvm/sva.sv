module sva (
    input logic               clk_i,
    input logic               rst_ni,
    input logic               lock_o,
    input logic               dbg_quad_done_o,
    input logic               dbg_quad_unresolved_o,
    input logic               freq_adj_valid_o,
    input logic signed [31:0] freq_adj_o
);
    
    // 1. Lock can only be asserted if the quadrant check is done
    property p_lock_done;
        @(posedge clk_i) disable iff (!rst_ni)
            lock_o |-> dbg_quad_done_o;
    endproperty
    a_lock_done: assert property (p_lock_done)
        else $error("[SVA] lock_o asserted without quad_done!");

    // 2. Lock cannot be asserted if the quadrant is unresolved
    property p_lock_no_unres;
        @(posedge clk_i) disable iff (!rst_ni)
            lock_o |-> !dbg_quad_unresolved_o;
    endproperty
    a_lock_no_unres: assert property (p_lock_no_unres)
        else $error("[SVA] lock_o asserted while quad is unresolved!");

    // 3. Frequency adjustment must not be X when valid is high
    property p_no_x_freq;
        @(posedge clk_i) disable iff (!rst_ni)
            freq_adj_valid_o |-> !$isunknown(freq_adj_o);
    endproperty
    a_no_x_freq: assert property (p_no_x_freq)
        else $error("[SVA] freq_adj_o is X while valid is high!");

endmodule