/**
 * ============================================================================
 * Design Name:    Complex Multiplier / Derotator Mixer (complex_multiplier)
 * Project Name:   Real-Time All-Digital Carrier & Timing Synchronization Unit
 * Organization:   Electronics Research Institute (ERI) - CLASH Challenge
 * Author:         Haneen Fady Kamel Shahin
 * ============================================================================
 * Description:
 *   Implements a 2-stage pipelined complex multiplier acting as a derotator 
 *   mixer for Costas loop carrier synchronization. Multiplies incoming 
 *   complex baseband symbols by quadrant-corrected NCO phasors (exp(-j*theta)) 
 *   to strip out residual carrier frequency and phase errors.
 * 
 * Specifications:
 *   - Data Width: Parameterized (default W = 16, Q1.15 fixed-point)
 *   - Latency: 2 clock cycles (Stage 1: DSP48 products, Stage 2: Add/Sub, Rnd, Sat)
 * ============================================================================
 */

module complex_multiplier #(
    parameter int W    = 16,     // data / trig width (Q1.(W-1))
    parameter int FRAC = W - 1
)(
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                s_axis_valid_i,         // input valid (symbol strobe)

    input  logic signed [W-1:0] s_axis_i_sym_i,
    input  logic signed [W-1:0] s_axis_q_sym_i,
    input  logic signed [W-1:0] cos_th,              
    input  logic signed [W-1:0] sin_th,

    output logic signed [W-1:0] m_axis_i_sym_o,
    output logic signed [W-1:0] m_axis_q_sym_o,
    output logic                m_axis_valid_o
);
    localparam int PW = 2*W;                       // product width
    localparam int SW = PW + 1;                    // sum width (for rounding)
    localparam logic signed [SW-1:0] RND = SW'(1) <<< (FRAC-1);
    localparam logic signed [W-1:0]  MAXV =  {1'b0, {(W-1){1'b1}}};
    localparam logic signed [W-1:0]  MINV =  {1'b1, {(W-1){1'b0}}};

    logic signed [PW-1:0] i_cos, q_sin, q_cos, i_sin;
    logic                 valid;

    // pipeline registers for valid strobe and input symbols
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid        <= 1'b0;
            m_axis_valid_o <= 1'b0;
        end else begin
            valid        <= s_axis_valid_i;
            m_axis_valid_o <= valid;
        end
    end

    // Stage 1: products. No reset on datapath so Vivado can pack into DSP48.
    always_ff @(posedge clk_i) begin
        if (s_axis_valid_i) begin
            i_cos <= s_axis_i_sym_i * cos_th;
            q_sin <= s_axis_q_sym_i * sin_th;
            q_cos <= s_axis_q_sym_i * cos_th;
            i_sin <= s_axis_i_sym_i * sin_th;
        end
    end

    // Stage 2: combine, round (add half LSB, then >>>), saturate
    function automatic logic signed [W-1:0] rnd_sat(input logic signed [SW-1:0] v);
        logic signed [SW-1:0] r;
        r = (v + RND) >>> FRAC;
        if      (r > SW'(MAXV)) return MAXV; 
        else if (r < SW'(MINV)) return MINV;
        else                    return r[W-1:0]; //if within range, return lower W bits
    endfunction
    
    always_ff @(posedge clk_i) begin
        if (valid) begin
            m_axis_i_sym_o <= rnd_sat(SW'(i_cos) + SW'(q_sin));
            m_axis_q_sym_o <= rnd_sat(SW'(q_cos) - SW'(i_sin));
        end
    end
endmodule
