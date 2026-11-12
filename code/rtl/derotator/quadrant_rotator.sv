// Design Name:  Quadrant rotator, full-circle derotation mapping (quadrant_rotator)
// Project:      Real-Time All-Digital Carrier and Timing Synchronization Unit
// Organization: Electronics Research Institute (ERI) - CLASH Challenge
// Author:       Haneen Fady Kamel Shahin
//
// Combinational 90-degree rotation of the input symbol by minus the NCO quadrant,
// x' = x * (-j)^q. Only signs and a swap depend on q, no multiplier. After this rotation the
// complex multiplier always uses the q = 0 equations with the 0..90 degree table values, so one
// quarter-wave table covers the full circle (derotator.md, "Equivalent form").
//   q = 0: x' = ( xi,  xq)
//   q = 1: x' = ( xq, -xi)
//   q = 2: x' = (-xi, -xq)
//   q = 3: x' = (-xq,  xi)
//
// Saturation: the negation is saturating, so -(-1.0) gives +0.99997 (0x7FFF) instead of
// overflowing Q1.15. This adds an error of 1 LSB, only when an input is exactly -1.0, and the
// reference model must do the same.

module quadrant_rotator #(
    parameter int DataWidth = 16
)(
    // Quadrant, the top two bits of the NCO phase
    input  logic        [1:0]           quad_i,
    input  logic signed [DataWidth-1:0] xi_i,
    input  logic signed [DataWidth-1:0] xq_i,
    // Rotated symbol x'
    output logic signed [DataWidth-1:0] xi_o,
    output logic signed [DataWidth-1:0] xq_o
);
    localparam logic signed [DataWidth-1:0] MAXV = {1'b0, {(DataWidth-1){1'b1}}};
    localparam logic signed [DataWidth-1:0] MINV = {1'b1, {(DataWidth-1){1'b0}}};

    // Negate with saturation: -(-1.0) would overflow Q1.15, so it gives the maximum value
    function automatic logic signed [DataWidth-1:0] neg(input logic signed [DataWidth-1:0] v);
        return (v == MINV) ? MAXV : -v;
    endfunction

    // Rotate by minus q * 90 degrees, see the table in the header. q = 3 is the default case.
    always_comb begin
        unique case (quad_i)
            2'd0:    begin xi_o =  xi_i;      xq_o =  xq_i;      end
            2'd1:    begin xi_o =  xq_i;      xq_o =  neg(xi_i); end
            2'd2:    begin xi_o =  neg(xi_i); xq_o =  neg(xq_i); end
            default: begin xi_o =  neg(xq_i); xq_o =  xi_i;      end
        endcase
    end
endmodule
