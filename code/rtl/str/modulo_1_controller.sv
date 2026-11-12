////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: Modulo-1 Controller (NCO) module.
// Date: 12-11-2026
// Description: Generates mid and current strobes, and calculates the fractional 
//              interval (mu) based on the PI filter output using a Taylor approximation.
////////////////////////////////////////////////////////////////////////////////

module modulo_1_controller 
    #( 
    // i have picked 10 bits for mu according to specs
    parameter integer MU_WIDTH = 10 
    )
    (
    // ------------ control signals ------------
    input logic clk_i,                // System clock
    input logic rst_ni,               // Asynchronous active-low reset
    input logic valid_sample_i,       // Valid sample input

    // ------------ inputs to the modulo-1 controller ------------
    // signed fixed point representation Q1.15 for the PI filter output
    // Q1.15 means: 1 sign bit, 0 integer bits, 15 fractional bits. 
    // The value is interpreted as (pi_i / 2^15).
    input logic signed [15:0] pi_i, 

    // ------------ outputs of the modulo-1 controller ------------
    output logic [MU_WIDTH-1:0] mu_o,  // Fractional delay value (0 to 1) used by the Farrow Interpolator
    output logic mid_strobe_o,         // 1-cycle pulse indicating the middle of the symbol (Half-symbol point)
    output logic current_strobe_o,     // 1-cycle pulse indicating the peak of the symbol (Current symbol)
    
    // signed fixed point representation Q1.15 for the NCO control word (step size)
    // This is the actual decrement value applied to the counter every valid sample.
    output logic signed [15:0] w_o 
    );

    // =========================================================================================
    // 1. CONSTANTS AND SIGNAL DECLARATIONS (Q1.15 Format)
    // =========================================================================================
    // In Q1.15, the value 1.0 is represented as 32768 (0x8000).
    // 0.75 is 0.75 * 32768 = 24576 (0xC000). 
    // i used 17 bits (17'h0C000) to handle the wrap-around logic without losing the sign bit 
    // because the counter needs to briefly hold a value up to 2.0 (0x10000) during arithmetic.
    localparam logic [16:0] M_INIT = 17'h0C000; // 0.75 in Q1.15
    
    // 0.25 is equal to 0x4000. this is the nominal step size because we have 4 samples per symbol.
    localparam logic [15:0] W_NOM  = 16'h4000;  // 0.25 in Q1.15
    
    // i made a register for the step size w to avoid timing issues and to ensure the counter uses the correct updated value
    logic signed [15:0] w;
    
    // the counter needs 17 bits to handle the wrap around 1.0 (0x10000) safely without overflow.
    // m_q is the current state of the counter. m_next is the combinational next state.
    logic signed [16:0] m_q, m_next;
    
    // w = 0.25 (Nominal) + pi (Error correction from the PI Loop Filter).
    // If pi is positive, the step is larger (faster countdown, sampling earlier).
    // If pi is negative, the step is smaller (slower countdown, sampling later).
    assign w = W_NOM + pi_i;
    assign w_o = w; // Outputting W for DFT/observation purposes

    // =========================================================================================
    // 2. CROSSING DETECTION (STROBE GENERATION)
    // =========================================================================================
    // The modulo-1 counter is divided into two regions to generate the strobes:
    // - Current region: from 0.75 down to 0.25 (where the symbol peak is expected).
    // - Mid region: from 0.25 down to 0.75 (where the zero-crossing/half-symbol is expected).
    // We detect a crossing by checking if the counter m_q was above the boundary in the previous cycle 
    // and m_next falls below it in the current cycle.
    logic curr_cross, mid_cross;
    
    // curr_cross: Triggers when the counter crosses 0.25 (0x4000) downwards. 
    // This indicates we have reached the optimal sampling instant for the CURRENT symbol.
    assign curr_cross = (m_q >= 17'h04000) && (m_next < 17'h04000) && valid_sample_i;
    
    // mid_cross: Triggers when the counter crosses 0.75 (0xC000) downwards. 
    // This indicates we have reached the MID point between two symbols.
    assign mid_cross  = (m_q >= 17'h0C000) && (m_next < 17'h0C000) && valid_sample_i;
    
    assign current_strobe_o = curr_cross; // Send pulse to Strobe Sampler
    assign mid_strobe_o     = mid_cross;  // Send pulse to Strobe Sampler

    // =========================================================================================
    // 3. COUNTER UPDATE AND WRAP-AROUND LOGIC
    // =========================================================================================
    // the counter decrements by w on every valid sample.
    // This is a pure combinational block (calculates m_next based on m_q).
    always_comb begin
        m_next = m_q - w; // Subtract the step size from the current counter value
        
        // if the counter goes below 0, it means we wrapped around the unit circle.
        // wrap it by adding 1.0 (17'h10000) to bring it back into the [0, 1) range.
        if (m_next < 0) begin
            m_next = m_next + 17'h10000;
        // if the counter exceeds 1.0 due to a very large positive PI error, wrap it by subtracting 1.0
        end else if (m_next >= 17'h10000) begin
            m_next = m_next - 17'h10000;
        end
    end

    // ------------ update the counter register ------------
    // This is a sequential block (flip-flops).
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_q <= M_INIT; // Initialize counter to 0.75 on reset
        end else if (valid_sample_i) begin // no need to update the counter if the input sample is not valid (saves power)
            m_q <= m_next; // Update the state with the calculated next value
        end
    end

    // =========================================================================================
    // 4. CALCULATE THE FRACTIONAL INTERVAL (mu)
    // =========================================================================================
    logic signed [16:0] eta;         // Distance traveled past the boundary
    logic signed [31:0] eta_pi_prod; // 32-bit register to hold the product of eta * pi
    logic signed [31:0] mu_calc;     // Intermediate calculation result for mu
    
    // eta is the distance the counter traveled past the boundary before crossing.
    // For example, if the boundary is 0.25 (0x4000) and m_q is 0.26 (0x428F), eta = 0x028F.
    // i did not add any extra bits to eta because its max value is bounded by w (which is around 0.25).
    always_comb begin
        if (curr_cross) begin
            eta = m_q - 17'h04000;       // Calculate distance past 0.25 boundary
        end else if (mid_cross) begin
            eta = m_q - 17'h0C000;       // Calculate distance past 0.75 boundary
        end else begin
            eta = '0;                    // If no crossing, eta is 0
        end
    end

    // The exact equation for the fractional interval is: mu = eta / W. 
    // Since division is extremely expensive in hardware, we use the first-order Taylor approximation:
    // 1/W = 1 / (0.25 + pi) = 4 / (1 + 4*pi) ≈ 4 * (1 - 4*pi) = 4 - 16*pi
    // So, mu ≈ eta * (4 - 16*pi) = 4*eta - 16*eta*pi
    
    // Math Breakdown (Q-Format tracking):
    // 1. eta is Q1.15 and pi is Q1.15, so the product (eta * pi) is Q2.30.
    // 2. (eta <<< 2) multiplies eta by 4. This produces a Q3.15 result.
    // 3. We need to subtract 16*eta*pi. 
    //    To multiply eta*pi by 16, we shift it left by 4 (making it Q2.26). 
    //    To align it with Q3.15, we shift right by 11 (30 - 15 - 4 = 11).
    always_comb begin
        eta_pi_prod = eta * pi_i;                      // Multiply eta and pi
        mu_calc     = (eta <<< 2) - (eta_pi_prod >>> 11); // mu = 4*eta - 16*eta*pi
        
        // 5. Saturation: Limit mu to the valid range [0, 1 - 2^-MU_WIDTH]
        // This prevents overflow and ensures mu can be safely represented in the required precision.
        if (mu_calc < 0) begin
            mu_o = '0;                                 // If negative, clamp to 0
        end else if (mu_calc >= 32'sh00008000) begin   // 0x8000 is 1.0 in Q1.15
            mu_o = (1 << MU_WIDTH) - 1;                // If >= 1.0, clamp to max value (all 1s)
        end else begin
            // Extract the top MU_WIDTH bits from the fractional part of mu_calc.
            // mu_calc is Q3.15, so the fractional part starts at bit 14 and goes down.
            mu_o = mu_calc[14 -: MU_WIDTH]; 
        end
    end

endmodule