////////////////////////////////////////////////////////////////////////////////
// Author: Hadeer Ghoneim
// Design: Proportional-Integral (PI) Loop Filter module.
// Date: 12-11-2026
// Description: Filters the timing error from the TED, applying proportional 
//              and integral gains with anti-windup and saturation limits.
////////////////////////////////////////////////////////////////////////////////

module pI_loop 
    #(
    // ------------ constants (Q1.15 format) ------------
    // KP: Proportional Gain. The correction applied immediately based on the current error.
    // KI: Integral Gain. The correction applied slowly to eliminate steady-state error.
    // MAX_V_PI: The absolute maximum value the output can reach (0.035 in Q1.15 = 16'h047A).
    parameter logic signed [15:0] KP = 16'sh0200,      // Proportional Gain
    parameter logic signed [15:0] KI = 16'sh0020,      // Integral Gain
    parameter logic signed [15:0] MAX_V_PI = 16'sh047A // Saturation Limit 0.035 in Q1.15 
    ) (
    // ------------ control signals ------------
    input  logic               clk_i,   // System clock
    input  logic               rst_ni,  // Asynchronous active-low reset
    input  logic               valid_i, // Valid pulse indicating a new error sample is ready

    // ------------ inputs ------------
    // error_i: The timing error from the Gardner TED. 
    // It is a 32-bit signed integer (result of multiplying 16-bit samples).
    input  logic signed [31:0] error_i,

    // ------------ outputs ------------
    // pi_o: The filtered output sent to the NCO (Modulo-1 Controller) in Q1.15 format.
    output logic signed [15:0] pi_o
    );

    // =========================================================================================
    // 1. SIGNAL DECLARATIONS
    // =========================================================================================
    // Why 48 bits for internal signals?
    // KP is 16 bits, error_i is 32 bits. Their product can be up to 48 bits (16 + 32 = 48).
    // We use 48 bits to prevent ANY overflow during multiplication and addition.
    logic signed [47:0] integrator_q, integrator_d; // Current and next state of the integrator
    logic signed [47:0] p_term, i_term;             // Proportional and Integral terms
    logic signed [47:0] pi_calc;                    // Unsaturated PI calculation
    logic               sat_high, sat_low;          // Saturation flags

    // =========================================================================================
    // 2. COMBINATIONAL CALCULATIONS (The Math)
    // =========================================================================================
    // KP and KI are Q1.15. error_i is a 32-bit integer.
    // We multiply them and shift right by 15 (>>> 15) to remove the fractional part of the gain.
    // This effectively scales the error by the gain coefficient.
    assign p_term  = (KP * error_i) >>> 15; 
    assign i_term  = (KI * error_i) >>> 15;
    
    // pi_calc is the sum of the Proportional path and the current Integrator value.
    assign pi_calc = p_term + integrator_q;

    // Check if the output exceeds the maximum allowed limits.
    assign sat_high = (pi_calc > MAX_V_PI);
    assign sat_low  = (pi_calc < -MAX_V_PI);

    // =========================================================================================
    // 3. ANTI-WINDUP LOGIC (Preventing the Integrator from blowing up)
    // =========================================================================================
    // Problem: If the error stays positive for a long time, the integrator keeps growing 
    // until it hits the saturation limit. When the error finally goes negative, it takes 
    // a long time for the integrator to unwind. This causes huge timing delays (overshoot).
    // Solution: Stop integrating if we are already saturated AND the error is pushing us 
    // further into saturation.
    always_comb begin
        integrator_d = integrator_q; // Default: hold current value
        
        if (valid_i) begin
            // If NOT saturated, OR if saturated but the error is pushing AGAINST the saturation
            if (!((sat_high && error_i > 0) || (sat_low && error_i < 0))) begin
                integrator_d = integrator_q + i_term; // Accumulate the integral term
            end
        end
    end

    // =========================================================================================
    // 4. SEQUENTIAL LOGIC (Updating the Integrator)
    // =========================================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            integrator_q <= '0; // Reset integrator to 0
        end else if (valid_i) begin // Only update when a valid error arrives
            integrator_q <= integrator_d; 
        end
    end

    // =========================================================================================
    // 5. OUTPUT SATURATION AND REGISTRATION
    // =========================================================================================
    // We clamp the final output to the MAX_V_PI limits before sending it to the NCO.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pi_o <= '0;
        end else if (valid_i) begin
            if (sat_high) begin
                pi_o <= MAX_V_PI;         // Clamp to positive max (e.g., +0.035)
            end else if (sat_low) begin
                pi_o <= -MAX_V_PI;        // Clamp to negative max (e.g., -0.035)
            end else begin
                // Take the lower 16 bits. Since pi_calc has the same scale as Q1.15, 
                // the lower 16 bits represent the correct fractional value.
                pi_o <= pi_calc[15:0]; 
            end
        end
    end

endmodule