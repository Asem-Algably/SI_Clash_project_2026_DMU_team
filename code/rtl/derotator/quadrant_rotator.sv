/**
 * ============================================================================
 * * Design Name:      Quadrant Rotator / Full-Circle De-rotation Mapping
 * * Project Name:     Real-Time All-Digital Carrier and Timing Synchronization Unit
 * * Organization:     Electronics Research Institute (ERI) - CLASH Challenge
 * * Author:           Haneen Fady Kamel Shahin
 * ============================================================================
 * * Description:
 *   Performs 90-degree quadrant-based complex rotation (multiplying by (-j)^q)
 *   to map full 360-degree derotation down to the 0 to 90 degree quarter-wave 
 *   sine/cosine lookup table region, minimizing hardware multiplier usage.
 * 
 * * Specifications:
 *   - Data Precision: Configurable signed fixed-point width (default 16-bit Q1.15)
 *   - Saturation Management: Custom `neg` function prevents two's-complement
 *     overflow during negation of minimum negative values (e.g., -(-1.0)).
 * ============================================================================
 */
module quadrant_rotator #(
    parameter int W = 16
)(
    input  logic [1:0]          quad_i,
    input  logic signed [W-1:0] xi_i,
    input  logic signed [W-1:0] xq_i,
    output logic signed [W-1:0] xi_o,
    output logic signed [W-1:0] xq_o
);
    localparam logic signed [W-1:0] MAXV = {1'b0, {(W-1){1'b1}}};
    localparam logic signed [W-1:0] MINV = {1'b1, {(W-1){1'b0}}};

    // negate with saturation (-(-1.0) would overflow Q1.15)
    function automatic logic signed [W-1:0] neg(input logic signed [W-1:0] v);
        return (v == MINV) ? MAXV : -v;
    endfunction

    // x' = x * (-j)^q   (spec: "Equivalent form")
    always_comb begin
        unique case (quad_i)
            2'd0:    begin xi_o =  xi_i;      xq_o =  xq_i;      end
            2'd1:    begin xi_o =  xq_i;      xq_o =  neg(xi_i); end
            2'd2:    begin xi_o =  neg(xi_i); xq_o =  neg(xq_i); end
            default: begin xi_o =  neg(xq_i); xq_o =  xi_i;      end
        endcase
    end
endmodule