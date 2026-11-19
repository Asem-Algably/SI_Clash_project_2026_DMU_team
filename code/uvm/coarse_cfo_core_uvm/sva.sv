module sva (
  input logic        clk_i,
  input logic        rst_ni,
  input logic        m_axis_valid_o,
  input logic signed [23:0] m_axis_cfo_o
);

  // When valid is high, CFO must not be X
  property p_no_x_on_valid;
    @(posedge clk_i) disable iff (!rst_ni)
      m_axis_valid_o |-> !$isunknown(m_axis_cfo_o);
  endproperty
  a_no_x_on_valid: assert property (p_no_x_on_valid)
    else $error("[SVA] m_axis_cfo_o is X while m_axis_valid_o is high");

endmodule